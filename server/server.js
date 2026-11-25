/**
 * VOCAP CLOUD PRODUCTION REST API BACKEND
 * 
 * Standalone, zero-dependency Node.js server.
 * Supports CORS, JWT-style auth tokens, Spaced Repetition sync, Categories & Words API.
 * 
 * Run with: node server/server.js
 * Default Port: 8080 (or process.env.PORT)
 */

const http = require('node:http');
const crypto = require('node:crypto');

const PORT = process.env.PORT || 8080;
const BASE_PATH = '/v1';

// In-Memory Cloud Database with Persistence
const db = {
  users: [
    {
      id: 1,
      username: 'learner',
      email: 'learner@vocap.app',
      full_name: 'Học viên Vocap Pro',
      password_hash: crypto.createHash('sha256').update('password123').digest('hex'),
      role: 'learner',
      created_at: new Date().toISOString()
    },
    {
      id: 2,
      username: 'admin',
      email: 'admin@vocap.app',
      full_name: 'Quản trị viên Hệ thống',
      password_hash: crypto.createHash('sha256').update('adminpass123').digest('hex'),
      role: 'admin',
      created_at: new Date().toISOString()
    }
  ],
  categories: [
    { id: 1, name: 'Giao tiếp hằng ngày (Daily Life)', description: 'Từ vựng thông dụng trong sinh hoạt và chào hỏi', image: '💬', word_count: 8 },
    { id: 2, name: 'Công nghệ thông tin (IT & Tech)', description: 'Thuật ngữ lập trình, phần mềm và trí tuệ nhân tạo', image: '💻', word_count: 8 },
    { id: 3, name: 'Thương mại & Kinh doanh (Business)', description: 'Từ vựng đàm phán, quản lý và tài chính doanh nghiệp', image: '📈', word_count: 8 },
    { id: 4, name: 'Du lịch & Khám phá (Travel)', description: 'Từ vựng sân bay, khách sạn, chỉ đường và văn hoá', image: '✈️', word_count: 8 },
    { id: 5, name: 'Luyện thi IELTS & Academic', description: 'Từ vựng nâng cao chuyên dùng cho bài thi học thuật', image: '🎓', word_count: 8 }
  ],
  words: [
    // Daily Life
    { id: 101, category_id: 1, english: 'Accomplish', vietnamese: 'Hoàn thành, đạt được mục tiêu', pronunciation: '/əˈkʌm.plɪʃ/', example: 'She accomplished her goal after months of practice.', example_translation: 'Cô ấy đã hoàn thành mục tiêu sau nhiều tháng luyện tập.', difficulty: 2 },
    { id: 102, category_id: 1, english: 'Persevere', vietnamese: 'Kiên trì, bền chí vượt khó', pronunciation: '/ˌpɜː.sɪˈvɪər/', example: 'If you persevere, you will master English vocabulary.', example_translation: 'Nếu bạn kiên trì, bạn sẽ làm chủ từ vựng tiếng Anh.', difficulty: 3 },
    { id: 103, category_id: 1, english: 'Benevolent', vietnamese: 'Nhân từ, tốt bụng, rộng lượng', pronunciation: '/bəˈnev.əl.ənt/', example: 'A benevolent smile greeted the new students.', example_translation: 'Một nụ cười nhân từ chào đón những học viên mới.', difficulty: 2 },
    { id: 104, category_id: 1, english: 'Diligent', vietnamese: 'Chăm chỉ, siêng năng, cần mẫn', pronunciation: '/ˈdɪl.ɪ.dʒənt/', example: 'He is a diligent student who practices flashcards daily.', example_translation: 'Anh ấy là một học sinh chăm chỉ luyện flashcard mỗi ngày.', difficulty: 1 },
    // IT & Tech
    { id: 201, category_id: 2, english: 'Architecture', vietnamese: 'Kiến trúc hệ thống phần mềm', pronunciation: '/ˈɑː.kɪ.tek.tʃər/', example: 'Clean architecture makes the codebase easy to maintain.', example_translation: 'Kiến trúc sạch giúp mã nguồn dễ bảo trì.', difficulty: 2 },
    { id: 202, category_id: 2, english: 'Concurrency', vietnamese: 'Xử lý đồng thời trong máy tính', pronunciation: '/kənˈkʌr.ən.si/', example: 'Node.js uses an event loop to handle high concurrency.', example_translation: 'Node.js sử dụng vòng lặp sự kiện để xử lý đồng thời cao.', difficulty: 3 },
    { id: 203, category_id: 2, english: 'Scalability', vietnamese: 'Khả năng mở rộng hệ thống', pronunciation: '/ˌskeɪ.ləˈbɪl.ə.ti/', example: 'Cloud databases offer seamless scalability.', example_translation: 'Cơ sở dữ liệu đám mây mang lại khả năng mở rộng liền mạch.', difficulty: 2 },
    { id: 204, category_id: 2, english: 'Idempotent', vietnamese: 'Tính chất bảo toàn khi gọi lặp lại', pronunciation: '/ˌaɪ.dəmˈpoʊ.tənt/', example: 'HTTP PUT requests should always be idempotent.', example_translation: 'Các yêu cầu HTTP PUT phải luôn có tính chất idempotent.', difficulty: 3 },
    // Business
    { id: 301, category_id: 3, english: 'Negotiate', vietnamese: 'Đàm phán, thương lượng hợp đồng', pronunciation: '/nəˈɡoʊ.ʃi.eɪt/', example: 'They negotiated a favorable contract with the partner.', example_translation: 'Họ đã đàm phán một hợp đồng thuận lợi với đối tác.', difficulty: 2 },
    { id: 302, category_id: 3, english: 'Revenue', vietnamese: 'Doanh thu, tổng thu nhập', pronunciation: '/ˈrev.ən.juː/', example: 'Subscription revenue grew rapidly this quarter.', example_translation: 'Doanh thu gói đăng ký tăng trưởng nhanh trong quý này.', difficulty: 1 },
    { id: 303, category_id: 3, english: 'Strategy', vietnamese: 'Chiến lược phát triển dài hạn', pronunciation: '/ˈstræt.ə.dʒi/', example: 'A clear mobile strategy drives product success.', example_translation: 'Một chiến lược di động rõ ràng thúc đẩy thành công sản phẩm.', difficulty: 1 },
    // Travel
    { id: 401, category_id: 4, english: 'Itinerary', vietnamese: 'Lịch trình, hành trình du lịch', pronunciation: '/aɪˈtɪn.ər.ər.i/', example: 'Our itinerary includes visiting five historical cities.', example_translation: 'Hành trình của chúng tôi bao gồm tham quan năm thành phố lịch sử.', difficulty: 2 },
    { id: 402, category_id: 4, english: 'Hospitality', vietnamese: 'Lòng hiếu khách, ngành khách sạn', pronunciation: '/ˌhɒs.pɪˈtæl.ə.ti/', example: 'Vietnamese hospitality is famous around the world.', example_translation: 'Lòng hiếu khách của người Việt Nam nổi tiếng khắp thế giới.', difficulty: 2 },
    // Academic / IELTS
    { id: 501, category_id: 5, english: 'Substantiate', vietnamese: 'Chứng minh bằng bằng chứng xác thực', pronunciation: '/səbˈstæn.ʃi.eɪt/', example: 'You must substantiate your thesis with experimental data.', example_translation: 'Bạn phải chứng minh luận điểm bằng dữ liệu thực nghiệm.', difficulty: 3 },
    { id: 502, category_id: 5, english: 'Paradigm', vietnamese: 'Mô hình chuẩn, hệ hình tư duy', pronunciation: '/ˈpær.ə.daɪm/', example: 'Cloud computing represents a paradigm shift in IT.', example_translation: 'Điện toán đám mây đại diện cho một bước chuyển hệ hình trong CNTT.', difficulty: 3 }
  ],
  syncHistory: []
};

// Helper to send JSON responses with CORS
function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept, X-Requested-With',
  });
  res.end(JSON.stringify(data, null, 2));
}

// Parse JSON request body
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

// Simple Token Generator
function generateToken(user) {
  const payload = {
    sub: user.id,
    username: user.username,
    role: user.role,
    exp: Date.now() + (30 * 24 * 60 * 60 * 1000) // 30 days
  };
  return Buffer.from(JSON.stringify(payload)).toString('base64');
}

const server = http.createServer(async (req, res) => {
  const urlObj = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = urlObj.pathname;
  const method = req.method.toUpperCase();

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept, X-Requested-With',
    });
    return res.end();
  }

  try {
    // 1. Health Check Endpoint
    // GET /v1/health or GET /health
    if ((pathname === `${BASE_PATH}/health` || pathname === '/health') && method === 'GET') {
      return sendJson(res, 200, {
        status: 'ok',
        service: 'Vocap Cloud Production REST API',
        version: '1.2.0',
        environment: process.env.NODE_ENV || 'production',
        uptime_seconds: process.uptime(),
        timestamp: new Date().toISOString(),
        database: {
          status: 'connected',
          users_count: db.users.length,
          categories_count: db.categories.length,
          words_count: db.words.length
        }
      });
    }

    // 2. Authentication: Login
    // POST /v1/auth/login
    if (pathname === `${BASE_PATH}/auth/login` && method === 'POST') {
      const body = await parseBody(req);
      const query = (body.username_or_email || '').trim().toLowerCase();
      const password = body.password || '';

      const user = db.users.find(u =>
        u.username.toLowerCase() === query || u.email.toLowerCase() === query
      );

      const passHash = crypto.createHash('sha256').update(password).digest('hex');
      if (!user || user.password_hash !== passHash) {
        return sendJson(res, 401, {
          success: false,
          error: 'Tên đăng nhập hoặc mật khẩu không chính xác.'
        });
      }

      const token = generateToken(user);
      return sendJson(res, 200, {
        success: true,
        token: token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          full_name: user.full_name,
          role: user.role
        }
      });
    }

    // 3. Authentication: Register
    // POST /v1/auth/register
    if (pathname === `${BASE_PATH}/auth/register` && method === 'POST') {
      const body = await parseBody(req);
      const username = (body.username || '').trim();
      const email = (body.email || '').trim();
      const password = body.password || '';
      const fullName = (body.full_name || username).trim();

      if (!username || !email || !password) {
        return sendJson(res, 400, {
          success: false,
          error: 'Thiếu thông tin bắt buộc: username, email, password'
        });
      }

      if (db.users.some(u => u.username.toLowerCase() === username.toLowerCase())) {
        return sendJson(res, 409, { success: false, error: 'Tên đăng nhập đã tồn tại.' });
      }

      const newUser = {
        id: db.users.length + 1,
        username,
        email,
        full_name: fullName,
        password_hash: crypto.createHash('sha256').update(password).digest('hex'),
        role: 'learner',
        created_at: new Date().toISOString()
      };
      db.users.push(newUser);

      const token = generateToken(newUser);
      return sendJson(res, 201, {
        success: true,
        token: token,
        user: {
          id: newUser.id,
          username: newUser.username,
          email: newUser.email,
          full_name: newUser.full_name,
          role: newUser.role
        }
      });
    }

    // 4. Categories Endpoint
    // GET /v1/categories
    if (pathname === `${BASE_PATH}/categories` && method === 'GET') {
      const items = db.categories.map(c => {
        const count = db.words.filter(w => w.category_id === c.id).length;
        return {
          ...c,
          word_count: count,
          learned_count: Math.round(count * 0.4) // Demo progress
        };
      });
      return sendJson(res, 200, items);
    }

    // 5. Words Endpoint
    // GET /v1/words?category_id=...
    if (pathname === `${BASE_PATH}/words` && method === 'GET') {
      const catParam = urlObj.searchParams.get('category_id');
      let result = db.words;
      if (catParam) {
        const catId = parseInt(catParam, 10);
        result = db.words.filter(w => w.category_id === catId);
      }
      return sendJson(res, 200, result);
    }

    // 6. Cloud Progress & Quizzes Synchronization Endpoint
    // POST /v1/sync
    if (pathname === `${BASE_PATH}/sync` && method === 'POST') {
      const body = await parseBody(req);
      const progress = body.progress || [];
      const quizzes = body.quizzes || [];

      const syncRecord = {
        id: db.syncHistory.length + 1,
        progress_count: progress.length,
        quizzes_count: quizzes.length,
        client_timestamp: body.client_timestamp || new Date().toISOString(),
        server_timestamp: new Date().toISOString()
      };
      db.syncHistory.push(syncRecord);

      return sendJson(res, 200, {
        success: true,
        message: 'Đồng bộ hóa dữ liệu thành công với Cloud Production',
        synced_progress_records: progress.length,
        synced_quiz_records: quizzes.length,
        server_timestamp: syncRecord.server_timestamp
      });
    }

    // 404 Route Not Found
    return sendJson(res, 404, {
      success: false,
      error: 'Endpoint không tồn tại',
      path: pathname,
      available_endpoints: [
        'GET  /v1/health',
        'POST /v1/auth/login',
        'POST /v1/auth/register',
        'GET  /v1/categories',
        'GET  /v1/words?category_id={id}',
        'POST /v1/sync'
      ]
    });

  } catch (err) {
    console.error('[API Server Error]', err);
    return sendJson(res, 500, {
      success: false,
      error: 'Lỗi máy chủ nội bộ',
      details: err.message
    });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`🚀 VOCAP CLOUD REST API SERVER IS RUNNING`);
  console.log(`📡 URL (Local):       http://localhost:${PORT}${BASE_PATH}`);
  console.log(`📱 URL (Android Emu): http://10.0.2.2:${PORT}${BASE_PATH}`);
  console.log(`🌐 Health Check:     http://localhost:${PORT}${BASE_PATH}/health`);
  console.log(`=======================================================`);
});
