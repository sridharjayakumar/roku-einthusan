const express = require('express');
const cors = require('cors');
const auth = require('./auth');
const scraper = require('./scraper');
const stream = require('./stream');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

let defaultToken = null;

async function autoLogin() {
  const email = process.env.EINTHUSAN_EMAIL;
  const password = process.env.EINTHUSAN_PASSWORD;
  if (!email || !password) {
    console.log('No EINTHUSAN_EMAIL/PASSWORD set - manual login required');
    return;
  }
  try {
    const result = await auth.login(email, password);
    defaultToken = result.token;
    console.log(`Auto-login successful for ${email}`);
  } catch (err) {
    console.error(`Auto-login failed: ${err.message}`);
  }
}

function getToken(req) {
  return req.headers['x-session-token'] || defaultToken;
}

app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password required' });
  }
  try {
    const result = await auth.login(email, password);
    defaultToken = result.token;
    res.json(result);
  } catch (err) {
    res.status(401).json({ error: err.message });
  }
});

app.get('/auth/status', async (req, res) => {
  const token = getToken(req);
  if (!token) {
    return res.status(401).json({ authenticated: false });
  }
  try {
    const status = await auth.checkSession(token);
    res.json(status);
  } catch (err) {
    res.status(401).json({ authenticated: false, error: err.message });
  }
});

app.get('/catalog/:lang', async (req, res) => {
  const token = getToken(req);
  try {
    const movies = await scraper.getCatalog(req.params.lang, token);
    res.json({ movies });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/search', async (req, res) => {
  const { lang, q } = req.query;
  const token = getToken(req);
  if (!lang || !q) {
    return res.status(400).json({ error: 'lang and q parameters required' });
  }
  try {
    const movies = await scraper.search(lang, q, token);
    res.json({ movies });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/meta/:id', async (req, res) => {
  const token = getToken(req);
  try {
    const meta = await scraper.getMeta(req.params.id, token);
    res.json(meta);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/stream/:id', async (req, res) => {
  const token = getToken(req);
  try {
    const result = await stream.getStreamUrl(req.params.id, token);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/play/:id', async (req, res) => {
  const token = getToken(req);
  try {
    const result = await stream.getStreamUrl(req.params.id, token);
    const streamUrl = result.mp4 || result.hls;
    if (!streamUrl) {
      return res.status(404).json({ error: 'No stream URL' });
    }

    const axios = require('axios');
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://einthusan.tv/'
    };

    if (req.headers.range) {
      headers['Range'] = req.headers.range;
    }

    const upstream = await axios.get(streamUrl, {
      headers,
      responseType: 'stream',
      maxRedirects: 5
    });

    res.status(upstream.status);
    if (upstream.headers['content-type']) {
      res.set('Content-Type', upstream.headers['content-type']);
    }
    if (upstream.headers['content-length']) {
      res.set('Content-Length', upstream.headers['content-length']);
    }
    if (upstream.headers['content-range']) {
      res.set('Content-Range', upstream.headers['content-range']);
    }
    if (upstream.headers['accept-ranges']) {
      res.set('Accept-Ranges', upstream.headers['accept-ranges']);
    }

    upstream.data.pipe(res);
  } catch (err) {
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    }
  }
});

app.get('/debug/catalog/:lang', async (req, res) => {
  const token = getToken(req);
  try {
    const { client } = auth.getClientForToken(token);
    const lang = req.params.lang;
    const cheerio = require('cheerio');
    const results = {};

    // Load the browse page to get pageId (CSRF token)
    const browsePage = await client.get(`/movie/browse/?lang=${lang}`);
    const $ = cheerio.load(browsePage.data);
    const pageId = $('[data-pageid]').first().attr('data-pageid') || '';
    const tabID = pageId + Math.floor(Math.random() * 1000);

    // Collect all data attributes and element IDs for clues
    const dataAttrs = [];
    $('[data-browse]').each((i, el) => dataAttrs.push({ attr: 'data-browse', val: $(el).attr('data-browse').substring(0, 100) }));
    $('[data-content]').each((i, el) => dataAttrs.push({ attr: 'data-content', val: $(el).attr('data-content').substring(0, 100) }));
    $('[id]').each((i, el) => {
      const id = $(el).attr('id');
      if (id && (id.includes('Movie') || id.includes('UI') || id.includes('Browse'))) {
        dataAttrs.push({ attr: 'id', val: id });
      }
    });
    results['page_clues'] = { pageId: pageId.substring(0, 30) + '...', dataAttrs };

    // Try AJAX with module names from the page
    const attempts = [
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIFeaturedFilms.GetContent' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIShowcasedFilms.GetContent' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIMovieFinder.Find' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIMovieFinder.Search' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'PGMovieBrowser.GetData' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'PGMovieBrowser.Browse' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIFeaturedFilms.Next' },
      { url: `/ajax/movie/browse/?lang=${lang}`, xEvent: 'UIShowcasedFilms.Next' },
    ];

    for (const attempt of attempts) {
      try {
        const params = new URLSearchParams();
        params.append('xEvent', attempt.xEvent);
        params.append('xJson', JSON.stringify({ Lang: lang, Page: 1, Find: 'Recent' }));
        params.append('arcVersion', '12');
        params.append('appVersion', '353');
        params.append('tabID', tabID);
        params.append('gorilla.csrf.Token', pageId);

        const ajaxRes = await client.post(attempt.url, params.toString(), {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': `https://einthusan.tv/movie/browse/?lang=${lang}`,
            'X-Requested-With': 'XMLHttpRequest'
          }
        });
        const data = JSON.stringify(ajaxRes.data);
        results[attempt.xEvent] = { status: ajaxRes.status, empty: data === '""' || data === '', data: data.substring(0, 800) };
      } catch (e) {
        results[attempt.xEvent] = { error: e.response ? `${e.response.status}` : e.message };
      }
    }

    // Test URL-based pagination on search
    const paginationTests = [
      `/movie/results/?lang=${lang}&query= &page=2`,
      `/movie/results/?lang=${lang}&query= &start=6`,
      `/movie/results/?lang=${lang}&query= &offset=6`,
      `/movie/results/?lang=${lang}&query=a&page=2`,
    ];
    for (const url of paginationTests) {
      try {
        const pRes = await client.get(url);
        const $p = cheerio.load(pRes.data);
        const movies = [];
        $p('#UIMovieSummary li').each((i, el) => {
          const title = $p(el).find('a.title h3').text().trim();
          if (title) movies.push(title);
        });
        results[url] = { count: movies.length, items: movies.slice(0, 6) };
      } catch (e) {
        results[url] = { error: e.message };
      }
    }

    // Multi-letter search to see if we get different results
    const letters = ['b', 'c', 'd', 'e', 'th'];
    for (const q of letters) {
      const url = `/movie/results/?lang=${lang}&query=${q}`;
      try {
        const sRes = await client.get(url);
        const $s = cheerio.load(sRes.data);
        const movies = [];
        $s('#UIMovieSummary li').each((i, el) => {
          const title = $s(el).find('a.title h3').text().trim();
          if (title) movies.push(title);
        });
        results[`letter_${q}`] = { count: movies.length, items: movies };
      } catch (e) {
        results[`letter_${q}`] = { error: e.message };
      }
    }

    res.json(results);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    authenticated: defaultToken !== null,
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', async () => {
  console.log(`Einthusan proxy running on port ${PORT}`);
  await autoLogin();
});
