const axios = require('axios');
const { CookieJar } = require('tough-cookie');
const { wrapper } = require('axios-cookiejar-support');
const cheerio = require('cheerio');
const crypto = require('crypto');
const NodeCache = require('node-cache');

const BASE_URL = 'https://einthusan.tv';
const sessions = new NodeCache({ stdTTL: 86400, checkperiod: 3600 });

function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

function createClient(cookieJar) {
  const jar = cookieJar || new CookieJar();
  const client = wrapper(axios.create({
    baseURL: BASE_URL,
    jar,
    withCredentials: true,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
  }));
  return { client, jar };
}

async function login(email, password) {
  const { client, jar } = createClient();

  const loginPage = await client.get('/login/');
  const $ = cheerio.load(loginPage.data);

  const pageId = $('[data-pageid]').attr('data-pageid');
  if (!pageId) {
    throw new Error('Could not extract page ID (CSRF token)');
  }

  const tabID = pageId + Math.floor(Math.random() * 1000);

  const params = new URLSearchParams();
  params.append('xEvent', 'PGLogin-Login');
  params.append('xJson', JSON.stringify({ Email: email, Password: password }));
  params.append('arcVersion', '12');
  params.append('appVersion', '353');
  params.append('tabID', tabID);
  params.append('gorilla.csrf.Token', pageId);

  const response = await client.post('/ajax/login/', params.toString(), {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Referer': `${BASE_URL}/login/`,
      'X-Requested-With': 'XMLHttpRequest'
    }
  });

  const responseData = response.data;
  const isError = typeof responseData === 'object' && responseData.Err === true;

  if (isError) {
    throw new Error(responseData.Message || 'Login failed - invalid credentials');
  }

  const token = generateToken();
  const serializedJar = await jar.serialize();
  sessions.set(token, {
    jar: serializedJar,
    email,
    loginTime: Date.now()
  });

  return { token, email, message: 'Login successful' };
}

async function checkSession(token) {
  const session = sessions.get(token);
  if (!session) {
    throw new Error('Session not found or expired');
  }
  return { authenticated: true, email: session.email };
}

function getClientForToken(token) {
  if (!token) return createClient();

  const session = sessions.get(token);
  if (!session) return createClient();

  const jar = CookieJar.deserializeSync(session.jar);
  return createClient(jar);
}

module.exports = { login, checkSession, getClientForToken };
