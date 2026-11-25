const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();

const auth = getAuth();
const db = getFirestore();

function requireAdmin(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập.');
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Bạn không có quyền quản trị.');
  }
}

function cleanUsername(value) {
  const username = String(value ?? '').trim();
  if (!/^[a-zA-Z0-9_.-]{3,30}$/.test(username)) {
    throw new HttpsError('invalid-argument', 'Tên đăng nhập phải có 3–30 ký tự hợp lệ.');
  }
  return username;
}

async function reserveUsername(uid, value) {
  const username = cleanUsername(value);
  const normalized = username.toLowerCase();
  const claimRef = db.collection('usernameClaims').doc(normalized);
  const profileRef = db.collection('users').doc(uid);
  await db.runTransaction(async (transaction) => {
    const [claim, profile] = await Promise.all([
      transaction.get(claimRef),
      transaction.get(profileRef),
    ]);
    if (claim.exists && claim.data().uid !== uid) {
      throw new HttpsError('already-exists', 'Tên đăng nhập đã được sử dụng.');
    }
    const oldUsername = String(profile.data()?.username ?? '').trim().toLowerCase();
    const oldRef = oldUsername ? db.collection('usernameClaims').doc(oldUsername) : null;
    const oldClaim = oldRef && oldUsername !== normalized
      ? await transaction.get(oldRef)
      : null;
    transaction.set(claimRef, { uid, username, updated_at: FieldValue.serverTimestamp() });
    if (oldRef && oldUsername !== normalized && oldClaim?.data()?.uid === uid) {
      transaction.delete(oldRef);
    }
    transaction.set(profileRef, { username, updated_at: new Date().toISOString() }, { merge: true });
  });
  return username;
}

async function ensureNotLastAdmin(uid) {
  const profile = await db.collection('users').doc(uid).get();
  if (profile.data()?.role !== 'admin') return;
  const admins = await db.collection('users').where('role', '==', 'admin').get();
  const activeAdmins = admins.docs.filter((doc) => doc.data().is_active !== false);
  if (activeAdmins.length <= 1) {
    throw new HttpsError('failed-precondition', 'Không thể xóa hoặc khóa Admin cuối cùng.');
  }
}

exports.claimUsername = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập.');
  return { username: await reserveUsername(request.auth.uid, request.data?.username) };
});

exports.adminAction = onCall(async (request) => {
  requireAdmin(request);
  const data = request.data ?? {};
  const uid = String(data.uid ?? '').trim();
  const profileRef = uid ? db.collection('users').doc(uid) : null;

  switch (data.action) {
    case 'createUser': {
      const email = String(data.email ?? '').trim().toLowerCase();
      const fullName = String(data.full_name ?? '').trim();
      const username = cleanUsername(data.username);
      const password = String(data.password ?? '');
      if (!email || !fullName || password.length < 10) {
        throw new HttpsError('invalid-argument', 'Thông tin tài khoản hoặc mật khẩu chưa hợp lệ.');
      }
      const created = await auth.createUser({ email, password, displayName: fullName });
      try {
        await reserveUsername(created.uid, username);
        await db.collection('users').doc(created.uid).set({
          full_name: fullName,
          email,
          username,
          role: 'user',
          is_active: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }, { merge: true });
      } catch (error) {
        await auth.deleteUser(created.uid);
        const claimRef = db.collection('usernameClaims').doc(username.toLowerCase());
        const claim = await claimRef.get();
        if (claim.data()?.uid === created.uid) await claimRef.delete();
        throw error;
      }
      return { uid: created.uid };
    }

    case 'updateUser': {
      if (!uid || !profileRef) throw new HttpsError('invalid-argument', 'Thiếu tài khoản.');
      const fullName = String(data.full_name ?? '').trim();
      const email = String(data.email ?? '').trim().toLowerCase();
      const username = cleanUsername(data.username);
      if (!fullName || !email) throw new HttpsError('invalid-argument', 'Thông tin tài khoản chưa hợp lệ.');
      await reserveUsername(uid, username);
      await auth.updateUser(uid, { email, displayName: fullName });
      await profileRef.set({ full_name: fullName, email, username, updated_at: new Date().toISOString() }, { merge: true });
      return { uid };
    }

    case 'setActive': {
      if (!uid || !profileRef) throw new HttpsError('invalid-argument', 'Thiếu tài khoản.');
      const active = data.active === true;
      if (!active && uid === request.auth.uid) {
        throw new HttpsError('failed-precondition', 'Không thể tự khóa tài khoản đang dùng.');
      }
      if (!active) await ensureNotLastAdmin(uid);
      await auth.updateUser(uid, { disabled: !active });
      await profileRef.set({ is_active: active, updated_at: new Date().toISOString() }, { merge: true });
      if (!active) await auth.revokeRefreshTokens(uid);
      return { uid, active };
    }

    case 'setRole': {
      if (!uid || !profileRef) throw new HttpsError('invalid-argument', 'Thiếu tài khoản.');
      const role = String(data.role ?? '');
      if (!['admin', 'user'].includes(role)) throw new HttpsError('invalid-argument', 'Vai trò không hợp lệ.');
      if (uid === request.auth.uid && role !== 'admin') {
        throw new HttpsError('failed-precondition', 'Không thể tự hạ quyền quản trị.');
      }
      if (role !== 'admin') await ensureNotLastAdmin(uid);
      const target = await auth.getUser(uid);
      const claims = { ...(target.customClaims ?? {}) };
      if (role === 'admin') claims.admin = true;
      else delete claims.admin;
      await auth.setCustomUserClaims(uid, claims);
      await profileRef.set({ role, updated_at: new Date().toISOString() }, { merge: true });
      return { uid, role };
    }

    case 'deleteUser': {
      if (!uid || !profileRef) throw new HttpsError('invalid-argument', 'Thiếu tài khoản.');
      if (uid === request.auth.uid) throw new HttpsError('failed-precondition', 'Không thể xóa tài khoản đang đăng nhập.');
      await ensureNotLastAdmin(uid);
      const profile = await profileRef.get();
      const username = String(profile.data()?.username ?? '').trim().toLowerCase();
      await auth.deleteUser(uid);
      await db.recursiveDelete(profileRef);
      if (username) {
        const claimRef = db.collection('usernameClaims').doc(username);
        const claim = await claimRef.get();
        if (claim.data()?.uid === uid) await claimRef.delete();
      }
      return { uid };
    }

    case 'resetPassword': {
      if (!uid || !profileRef) throw new HttpsError('invalid-argument', 'Thiếu tài khoản.');
      const password = String(data.password ?? '');
      if (password.length < 10) throw new HttpsError('invalid-argument', 'Mật khẩu cần ít nhất 10 ký tự.');
      await auth.updateUser(uid, { password });
      await auth.revokeRefreshTokens(uid);
      return { uid };
    }

    default:
      throw new HttpsError('invalid-argument', 'Thao tác quản trị không hợp lệ.');
  }
});
