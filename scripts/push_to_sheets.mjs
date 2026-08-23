// © AngelaMos | 2026
// scripts/push_to_sheets.mjs
//
// Pushes site/history/{global,indonesia}_timeseries.csv into two tabs of a
// Google Sheet, so a Looker Studio report built on that Sheet stays current
// after every scheduled scrape. Requires GOOGLE_SERVICE_ACCOUNT_KEY (the
// service account's JSON key, as a string) and GOOGLE_SHEET_ID env vars.
// See README2.md "Looker Studio dashboard" for one-time setup.

import { readFileSync } from "node:fs";
import { google } from "googleapis";

const keyJson = process.env.GOOGLE_SERVICE_ACCOUNT_KEY;
const sheetId = process.env.GOOGLE_SHEET_ID;

if (!keyJson || !sheetId) {
  console.log("GOOGLE_SERVICE_ACCOUNT_KEY or GOOGLE_SHEET_ID not set — skipping Google Sheets sync.");
  process.exit(0);
}

function parseCsv(text) {
  const normalized = text.replace(/\r\n/g, "\n");
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < normalized.length; i++) {
    const c = normalized[i];

    if (inQuotes) {
      if (c === '"') {
        if (normalized[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ",") {
      row.push(field);
      field = "";
    } else if (c === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += c;
    }
  }

  if (field !== "" || row.length) {
    row.push(field);
    rows.push(row);
  }

  return rows.filter((r) => r.length > 1 || r[0] !== "");
}

const credentials = JSON.parse(keyJson);
const auth = new google.auth.GoogleAuth({
  credentials,
  scopes: ["https://www.googleapis.com/auth/spreadsheets"],
});
const sheets = google.sheets({ version: "v4", auth });

async function ensureTab(tabName) {
  const meta = await sheets.spreadsheets.get({ spreadsheetId: sheetId });
  const exists = meta.data.sheets.some((s) => s.properties.title === tabName);

  if (!exists) {
    await sheets.spreadsheets.batchUpdate({
      spreadsheetId: sheetId,
      requestBody: { requests: [{ addSheet: { properties: { title: tabName } } }] },
    });
  }
}

async function pushTab(tabName, csvPath) {
  const rows = parseCsv(readFileSync(csvPath, "utf8"));
  if (!rows.length) {
    console.log(`${csvPath} is empty, skipping ${tabName}`);
    return;
  }

  await ensureTab(tabName);
  await sheets.spreadsheets.values.clear({ spreadsheetId: sheetId, range: `${tabName}!A:Z` });
  await sheets.spreadsheets.values.update({
    spreadsheetId: sheetId,
    range: `${tabName}!A1`,
    valueInputOption: "RAW",
    requestBody: { values: rows },
  });

  console.log(`Synced ${rows.length - 1} rows to tab "${tabName}"`);
}

await pushTab("Global", "site/history/global_timeseries.csv");
await pushTab("Indonesia", "site/history/indonesia_timeseries.csv");
