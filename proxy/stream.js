const cheerio = require('cheerio');
const axios = require('axios');
const NodeCache = require('node-cache');
const auth = require('./auth');

const streamCache = new NodeCache({ stdTTL: 600, checkperiod: 300 });
const BASE_URL = 'https://einthusan.tv';

function decrypt(encoded) {
  // jsoncrypto.decrypt: rearrange then base64 decode
  let e = encoded;
  e = e.slice(0, 10) + e.slice(e.length - 1) + e.slice(12, e.length - 1);
  const decoded = Buffer.from(e, 'base64').toString('utf8');
  return JSON.parse(decoded);
}

function encrypt(data) {
  // jsoncrypto.encrypt: base64 encode then rearrange (reverse of decrypt)
  const json = JSON.stringify(data);
  let e = Buffer.from(json).toString('base64');
  // Reverse the decrypt rearrangement:
  // decrypt does: result = e[0:10] + e[-1] + e[12:-1]
  // so encrypt must produce something that when decrypted gives back original
  // decrypt input: e[0:10] is positions 0-9, e[-1] is last char, e[12:-1] is positions 12 to second-to-last
  // decrypt output: e[0:10] + e[last] + e[12:last-1]
  // To reverse: if decrypted = base64(json), we need to find encrypted such that
  // encrypted[0:10] + encrypted[-1] + encrypted[12:-1] = decrypted
  // This means: decrypted[0:10] = encrypted[0:10], decrypted[10] = encrypted[-1], decrypted[11:] = encrypted[12:-1]
  // So: encrypted[0:10] = decrypted[0:10]
  //     encrypted[-1] = decrypted[10]
  //     encrypted[12:-1] = decrypted[11:]
  //     encrypted[10:12] = any 2 chars (they get dropped)
  const decrypted = e;
  const enc = decrypted.slice(0, 10) + 'XX' + decrypted.slice(11) + decrypted.slice(10, 11);
  return enc;
}

async function getStreamUrl(id, token) {
  const cacheKey = `stream_${id}_${token || 'anon'}`;
  const cached = streamCache.get(cacheKey);
  if (cached) return cached;

  const { client } = auth.getClientForToken(token);

  // Step 1: Load the movie page (lang=tamil as default, server redirects to correct lang)
  const pageUrl = `/movie/watch/${id}/?lang=tamil`;
  const response = await client.get(pageUrl);
  const $ = cheerio.load(response.data);

  // Get the actual URL after redirects (to capture the correct lang param)
  const actualUrl = response.request?.res?.responseUrl || response.config?.url || pageUrl;
  const langMatch = actualUrl.match(/[?&]lang=([^&]+)/);
  const lang = langMatch ? langMatch[1] : 'tamil';

  // Step 2: Get the encrypted pingables and page ID
  const playerEl = $('[data-ejpingables]');
  if (!playerEl.length) {
    throw new Error('Video player not found - may require login');
  }

  const ejPingables = playerEl.attr('data-ejpingables');
  const pageId = $('[data-pageid]').attr('data-pageid') || '';
  console.log('Movie lang:', lang, 'ejPingables length:', ejPingables?.length);

  // Step 3: Decrypt pingables to get CDN server list
  let pingUrls;
  try {
    pingUrls = decrypt(ejPingables);
  } catch (e) {
    throw new Error('Failed to decrypt pingables: ' + e.message);
  }

  // Step 4: Send PingOutcome to get real video links
  // Encrypt the ping URLs as "outcomes" (just pass them back sorted)
  const encryptedOutcomes = encrypt(pingUrls);
  const tabID = pageId + Math.floor(Math.random() * 1000);

  const params = new URLSearchParams();
  params.append('xEvent', 'UIVideoPlayer.PingOutcome');
  params.append('xJson', JSON.stringify({ EJOutcomes: encryptedOutcomes, NativeHLS: true }));
  params.append('arcVersion', '12');
  params.append('appVersion', '353');
  params.append('tabID', tabID);
  params.append('gorilla.csrf.Token', pageId);

  const ajaxUrl = `/ajax/movie/watch/${id}/?lang=${lang}`;
  console.log('Sending PingOutcome to:', ajaxUrl);
  console.log('pageId:', pageId.slice(0, 20) + '...');
  console.log('encryptedOutcomes:', encryptedOutcomes.slice(0, 50) + '...');

  const ajaxResponse = await client.post(ajaxUrl, params.toString(), {
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Referer': `${BASE_URL}/movie/watch/${id}/?lang=${lang}`,
      'X-Requested-With': 'XMLHttpRequest'
    }
  });

  console.log('PingOutcome status:', ajaxResponse.status);
  console.log('PingOutcome headers:', JSON.stringify(ajaxResponse.headers).slice(0, 200));

  // Step 5: Extract EJLinks from response
  // Response format: {Event: "UIVideoPlayer.initalize", Data: {EJLinks: "..."}}
  const ajaxData = ajaxResponse.data;
  let ejLinks;

  if (typeof ajaxData === 'object') {
    if (ajaxData.Data && ajaxData.Data.EJLinks) {
      ejLinks = ajaxData.Data.EJLinks;
    } else if (ajaxData.EJLinks) {
      ejLinks = ajaxData.EJLinks;
    }
  } else if (typeof ajaxData === 'string') {
    try {
      const parsed = JSON.parse(ajaxData);
      if (parsed.Data && parsed.Data.EJLinks) {
        ejLinks = parsed.Data.EJLinks;
      } else if (parsed.EJLinks) {
        ejLinks = parsed.EJLinks;
      }
    } catch (e) {}
  }

  if (!ejLinks) {
    console.log('PingOutcome response:', typeof ajaxData, JSON.stringify(ajaxData).slice(0, 500));
    throw new Error('Could not find EJLinks in response');
  }

  // Step 6: Decrypt the EJLinks to get actual video URLs
  let videoLinks;
  try {
    videoLinks = decrypt(ejLinks);
  } catch (e) {
    throw new Error('Failed to decrypt EJLinks: ' + e.message);
  }

  const result = {
    mp4: videoLinks.MP4Link || '',
    hls: videoLinks.HLSLink || ''
  };

  if (result.mp4 || result.hls) {
    streamCache.set(cacheKey, result);
  }

  return result;
}

module.exports = { getStreamUrl };
