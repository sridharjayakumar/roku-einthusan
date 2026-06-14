const cheerio = require('cheerio');
const NodeCache = require('node-cache');
const auth = require('./auth');

const BASE_URL = 'https://einthusan.tv';
const catalogCache = new NodeCache({ stdTTL: 1800, checkperiod: 600 });
const metaCache = new NodeCache({ stdTTL: 1800, checkperiod: 600 });

const LANGUAGES = ['hindi', 'tamil', 'telugu', 'malayalam', 'kannada', 'bengali', 'marathi', 'punjabi'];

function fixPosterUrl(src) {
  if (!src) return '';
  if (src.startsWith('//')) return 'https:' + src;
  if (src.startsWith('http')) return src;
  return BASE_URL + src;
}

function parseMovieList($) {
  const movies = [];
  $('#UIMovieSummary li').each((i, el) => {
    const $el = $(el);
    const titleEl = $el.find('a.title');
    const href = titleEl.attr('href') || '';
    const idMatch = href.match(/\/movie\/watch\/([^/?]+)/);
    if (!idMatch) return;

    const id = idMatch[1];
    const title = titleEl.find('h3').text().trim();
    const poster = $el.find('div.block1 a img').attr('src') || '';
    const year = $el.find('div.info p').first().contents().first().text().trim();

    movies.push({
      id,
      title,
      poster: fixPosterUrl(poster),
      year
    });
  });
  return movies;
}

async function getCatalog(lang, token) {
  if (!LANGUAGES.includes(lang.toLowerCase())) {
    throw new Error(`Unsupported language: ${lang}`);
  }

  const cacheKey = `catalog_${lang}_v3`;
  const cached = catalogCache.get(cacheKey);
  if (cached) return cached;

  const { client } = auth.getClientForToken(token);
  const allMovies = [];
  const maxPages = 5;

  for (let page = 1; page <= maxPages; page++) {
    const url = `/movie/results/?lang=${lang}&query=${encodeURIComponent(' ')}&page=${page}`;
    const response = await client.get(url);
    const $ = cheerio.load(response.data);
    const movies = parseMovieList($);
    if (movies.length === 0) break;
    allMovies.push(...movies);
  }

  console.log(`Catalog ${lang}: fetched ${allMovies.length} movies across up to ${maxPages} pages`);

  if (allMovies.length > 0) {
    catalogCache.set(cacheKey, allMovies);
  }
  return allMovies;
}

async function search(lang, query, token) {
  const { client } = auth.getClientForToken(token);
  const url = `/movie/results/?lang=${lang}&query=${encodeURIComponent(query)}`;
  const response = await client.get(url);
  const $ = cheerio.load(response.data);
  return parseMovieList($);
}

async function getMeta(id, token) {
  const cacheKey = `meta_${id}`;
  const cached = metaCache.get(cacheKey);
  if (cached) return cached;

  const { client } = auth.getClientForToken(token);
  const url = `/movie/watch/${id}/`;
  const response = await client.get(url);
  const $ = cheerio.load(response.data);

  const summary = $('#UIMovieSummary');
  const title = summary.find('a.title h3').text().trim();
  const poster = summary.find('div.block1 a img').attr('src') || '';
  const year = summary.find('div.info p').first().contents().first().text().trim();
  const synopsis = summary.find('p.synopsis').text().trim();

  const cast = [];
  summary.find('div.prof p').each((i, el) => {
    const name = $(el).text().trim();
    if (name) cast.push(name);
  });

  let trailer = '';
  const trailerEl = summary.find('div.extras a').eq(1);
  if (trailerEl.length) {
    const trailerHref = trailerEl.attr('href') || '';
    const ytMatch = trailerHref.match(/v=([^&]+)/);
    if (ytMatch) trailer = `https://www.youtube.com/watch?v=${ytMatch[1]}`;
  }

  const meta = {
    id,
    title,
    poster: fixPosterUrl(poster),
    year,
    synopsis,
    cast,
    trailer
  };

  metaCache.set(cacheKey, meta);
  return meta;
}

module.exports = { getCatalog, search, getMeta, LANGUAGES };
