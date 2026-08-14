import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const sourcePath = "C:/Users/simen/Downloads/employee_numbers.txt";
const envPath = "C:/Users/simen/Documents/Codex/ServiceNow/.env";
const outputDir = "C:/Users/simen/.codex/skills/servicenow-pdi/outputs/hr-user-reconciliation-20260807";
const outputPath = path.join(outputDir, "Vaar_Energi_HR_User_Reconciliation_2026-08-07.xlsx");
const instance = "https://varenergisandbox.service-now.com";

function parseEnv(text) {
  const result = {};
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*([^#=\s]+)\s*=\s*(.*)\s*$/);
    if (!match) continue;
    result[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
  }
  return result;
}

function asText(value) {
  return value === null || value === undefined ? "" : String(value).trim();
}

function columnName(index) {
  let n = index;
  let name = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = Math.floor((n - 1) / 26);
  }
  return name;
}

function applyHeader(range) {
  range.format = {
    fill: "#17324D",
    font: { bold: true, color: "#FFFFFF" },
    verticalAlignment: "center",
    wrapText: true,
    borders: { preset: "outside", style: "thin", color: "#17324D" },
  };
  range.format.rowHeight = 30;
}

function styleDataSheet(sheet, headers, rowCount, widths) {
  sheet.showGridLines = false;
  sheet.freezePanes.freezeRows(1);
  const lastCol = columnName(headers.length);
  applyHeader(sheet.getRange(`A1:${lastCol}1`));
  if (rowCount > 0) {
    const table = sheet.tables.add(`A1:${lastCol}${rowCount + 1}`, true, `${sheet.name.replace(/[^A-Za-z0-9]/g, "")}Table`);
    table.style = "TableStyleMedium2";
    table.showFilterButton = true;
  }
  widths.forEach((width, idx) => {
    sheet.getRange(`${columnName(idx + 1)}:${columnName(idx + 1)}`).format.columnWidth = width;
  });
  if (rowCount > 0) {
    sheet.getRange(`A2:${lastCol}${rowCount + 1}`).format.verticalAlignment = "center";
  }
}

const [sourceText, envText] = await Promise.all([
  fs.readFile(sourcePath, "utf8"),
  fs.readFile(envPath, "utf8"),
]);
const env = parseEnv(envText);
const user = env.SN_OTHER_USER;
const password = env.SN_OTHER_PASS;
if (!user || !password) throw new Error("ServiceNow Sandbox credentials were not found in the configured environment profile.");

const auth = Buffer.from(`${user}:${password}`, "utf8").toString("base64");
const fields = "sys_id,user_name,name,employee_number,active,sys_updated_on";
const url = `${instance}/api/now/table/sys_user?sysparm_fields=${encodeURIComponent(fields)}&sysparm_limit=10000&sysparm_exclude_reference_link=true`;
const response = await fetch(url, { headers: { Authorization: `Basic ${auth}`, Accept: "application/json" } });
if (!response.ok) throw new Error(`ServiceNow user retrieval failed with HTTP ${response.status}.`);
const payload = await response.json();
const allUsers = Array.isArray(payload.result) ? payload.result : [];

const sapNumbers = sourceText
  .split(/\r?\n/)
  .map((value) => value.trim())
  .filter(Boolean);
const sapSet = new Set(sapNumbers);
const sapGroups = new Map();
for (const number of sapNumbers) sapGroups.set(number, (sapGroups.get(number) || 0) + 1);

const usersWithEmployeeNumber = allUsers
  .map((row) => ({
    employeeNumber: asText(row.employee_number),
    name: asText(row.name),
    userName: asText(row.user_name),
    active: asText(row.active) === "true",
    sysId: asText(row.sys_id),
    updatedOn: asText(row.sys_updated_on),
  }))
  .filter((row) => row.employeeNumber);

const usersByEmployeeNumber = new Map();
for (const row of usersWithEmployeeNumber) {
  if (!usersByEmployeeNumber.has(row.employeeNumber)) usersByEmployeeNumber.set(row.employeeNumber, []);
  usersByEmployeeNumber.get(row.employeeNumber).push(row);
}

const reconciliation = sapNumbers.map((employeeNumber) => {
  const matches = usersByEmployeeNumber.get(employeeNumber) || [];
  const primary = matches[0];
  return {
    employeeNumber,
    status: primary ? "Matched" : "Missing",
    name: primary?.name || "",
    userName: primary?.userName || "",
    activeStatus: primary ? (primary.active ? "Active" : "Inactive") : "",
    sysId: primary?.sysId || "",
    updatedOn: primary?.updatedOn || "",
    matchCount: matches.length,
  };
});

const missing = reconciliation.filter((row) => row.status === "Missing");
const matched = reconciliation.filter((row) => row.status === "Matched");
const serviceNowOnly = usersWithEmployeeNumber.filter((row) => !sapSet.has(row.employeeNumber));
const sapDuplicates = [...sapGroups.entries()].filter(([, count]) => count > 1);
const snDuplicates = [...usersByEmployeeNumber.entries()].filter(([, rows]) => rows.length > 1);
const inactiveMatches = matched.filter((row) => row.activeStatus === "Inactive");
const generatedAt = new Date().toLocaleString("en-GB", { timeZone: "Europe/Oslo", hour12: false });

const workbook = Workbook.create();
workbook.comments.setSelf({ displayName: "Simen Staaby Knudsen" });

const summary = workbook.worksheets.add("Summary");
const missingSheet = workbook.worksheets.add("Missing in ServiceNow");
const reconciliationSheet = workbook.worksheets.add("Reconciliation");
const snOnlySheet = workbook.worksheets.add("ServiceNow Only");
const snInventorySheet = workbook.worksheets.add("SN With Employee No");
const metricsSheet = workbook.worksheets.add("Source Metrics");

summary.showGridLines = false;
summary.getRange("A1:F1").merge();
summary.getRange("A1").values = [["Vår Energi HR User Reconciliation"]];
summary.getRange("A1:F1").format = {
  fill: "#17324D",
  font: { bold: true, color: "#FFFFFF", size: 18 },
  verticalAlignment: "center",
};
summary.getRange("A1:F1").format.rowHeight = 42;
summary.getRange("A2:F2").merge();
summary.getRange("A2").values = [[`SAP SuccessFactors employee numbers compared with ${instance} on ${generatedAt} (Europe/Oslo)`]];
summary.getRange("A2:F2").format = { fill: "#E9F0F5", font: { color: "#334E68", italic: true }, wrapText: true };
summary.getRange("A2:F2").format.rowHeight = 30;

summary.getRange("A4:B4").values = [["Metric", "Result"]];
applyHeader(summary.getRange("A4:B4"));
summary.getRange("A5:A15").values = [
  ["SAP employee numbers"],
  ["Matched in ServiceNow"],
  ["Missing from ServiceNow"],
  ["SAP match rate"],
  ["ServiceNow users total"],
  ["ServiceNow users with employee number"],
  ["ServiceNow users without employee number"],
  ["ServiceNow employee numbers not in SAP list"],
  ["Matched only to inactive users"],
  ["Duplicate SAP employee numbers"],
  ["Duplicate ServiceNow employee numbers"],
];
const reconLast = reconciliation.length + 1;
const snLast = usersWithEmployeeNumber.length + 1;
const snOnlyLast = serviceNowOnly.length + 1;
summary.getRange("B5:B15").formulas = [
  [`=COUNTA('Reconciliation'!$A$2:$A$${reconLast})`],
  [`=COUNTIF('Reconciliation'!$B$2:$B$${reconLast},"Matched")`],
  [`=COUNTIF('Reconciliation'!$B$2:$B$${reconLast},"Missing")`],
  ["=IFERROR(B6/B5,0)"],
  ["='Source Metrics'!$B$2"],
  [`=COUNTA('SN With Employee No'!$A$2:$A$${snLast})`],
  ["=B9-B10"],
  [serviceNowOnly.length ? `=COUNTA('ServiceNow Only'!$A$2:$A$${snOnlyLast})` : "=0"],
  [`=COUNTIFS('Reconciliation'!$B$2:$B$${reconLast},"Matched",'Reconciliation'!$E$2:$E$${reconLast},"Inactive")`],
  ["='Source Metrics'!$B$6"],
  ["='Source Metrics'!$B$7"],
];
summary.getRange("A5:B15").format.borders = { preset: "outside", style: "thin", color: "#AAB7C4" };
summary.getRange("B5:B15").format = { font: { bold: true, color: "#17324D" }, horizontalAlignment: "right" };
summary.getRange("B8").format.numberFormat = "0.0%";
summary.getRange("A:A").format.columnWidth = 39;
summary.getRange("B:B").format.columnWidth = 17;

summary.getRange("D4:F4").merge();
summary.getRange("D4").values = [["Conclusion"]];
applyHeader(summary.getRange("D4:F4"));
summary.getRange("D5:F8").merge();
summary.getRange("D5").values = [[`${missing.length} of ${sapNumbers.length} SAP employee numbers have no exact match in Sandbox sys_user.employee_number. The HR Profile API cannot process these people until a corresponding ServiceNow user exists with the same employee number.`]];
summary.getRange("D5:F8").format = { fill: "#FDECEC", font: { color: "#8A1C1C", bold: true }, wrapText: true, verticalAlignment: "center", borders: { preset: "outside", style: "thin", color: "#E59A9A" } };

summary.getRange("D10:F10").merge();
summary.getRange("D10").values = [["Recommended investigation"]];
applyHeader(summary.getRange("D10:F10"));
summary.getRange("D11:F15").merge();
summary.getRange("D11").values = [["1. Confirm whether the missing SAP people are within the Entra ID provisioning scope.\n2. Check whether their Entra accounts exist but employeeNumber is empty or mapped differently.\n3. Confirm treatment of future hires, terminated workers, contractors, and non-person accounts.\n4. Re-run this reconciliation after Entra synchronization before the HR Profile full load."]];
summary.getRange("D11:F15").format = { fill: "#FFF5DB", font: { color: "#5B4600" }, wrapText: true, verticalAlignment: "top", borders: { preset: "outside", style: "thin", color: "#D8BD64" } };
summary.getRange("D:F").format.columnWidth = 22;
summary.getRange("D5:F15").format.rowHeight = 24;

summary.getRange("A18:F18").merge();
summary.getRange("A18").values = [["Interpretation boundary"]];
applyHeader(summary.getRange("A18:F18"));
summary.getRange("A19:F21").merge();
summary.getRange("A19").values = [["This report proves whether an exact employee-number match exists in the Sandbox sys_user table. It does not by itself identify the upstream root cause. The missing list must be reconciled with Entra ID provisioning logs and SuccessFactors worker status before assigning ownership."]];
summary.getRange("A19:F21").format = { fill: "#EDF4F8", wrapText: true, verticalAlignment: "center", borders: { preset: "outside", style: "thin", color: "#AAB7C4" } };

const missingHeaders = ["SAP Employee Number", "Finding", "Required Action"];
missingSheet.getRange(`A1:C${missing.length + 1}`).values = [
  missingHeaders,
  ...missing.map((row) => [row.employeeNumber, "No exact sys_user.employee_number match", "Verify Entra ID account and employeeNumber mapping"]),
];
styleDataSheet(missingSheet, missingHeaders, missing.length, [20, 38, 48]);
missingSheet.getRange(`A2:A${missing.length + 1}`).format.numberFormat = "@";
missingSheet.getRange(`B2:B${missing.length + 1}`).format.font = { color: "#A61B1B" };

const reconciliationHeaders = ["SAP Employee Number", "Match Status", "ServiceNow Name", "ServiceNow User Name", "Active Status", "ServiceNow Sys ID", "ServiceNow Updated On", "SN Match Count"];
reconciliationSheet.getRange(`A1:H${reconciliation.length + 1}`).values = [
  reconciliationHeaders,
  ...reconciliation.map((row) => [row.employeeNumber, row.status, row.name, row.userName, row.activeStatus, row.sysId, row.updatedOn, row.matchCount]),
];
styleDataSheet(reconciliationSheet, reconciliationHeaders, reconciliation.length, [20, 15, 27, 34, 15, 35, 22, 15]);
reconciliationSheet.getRange(`A2:A${reconciliation.length + 1}`).format.numberFormat = "@";
reconciliationSheet.getRange(`B2:B${reconciliation.length + 1}`).conditionalFormats.add("containsText", { text: "Missing", format: { fill: "#FDECEC", font: { color: "#A61B1B", bold: true } } });
reconciliationSheet.getRange(`B2:B${reconciliation.length + 1}`).conditionalFormats.add("containsText", { text: "Matched", format: { fill: "#E8F5EC", font: { color: "#176B37" } } });
reconciliationSheet.getRange(`E2:E${reconciliation.length + 1}`).conditionalFormats.add("containsText", { text: "Inactive", format: { fill: "#FFF1D6", font: { color: "#805500" } } });

const snOnlyHeaders = ["ServiceNow Employee Number", "Name", "User Name", "Active Status", "Sys ID", "Updated On", "Finding"];
snOnlySheet.getRange(`A1:G${serviceNowOnly.length + 1}`).values = [
  snOnlyHeaders,
  ...serviceNowOnly.map((row) => [row.employeeNumber, row.name, row.userName, row.active ? "Active" : "Inactive", row.sysId, row.updatedOn, "Not present in supplied SAP list"]),
];
styleDataSheet(snOnlySheet, snOnlyHeaders, serviceNowOnly.length, [24, 27, 34, 15, 35, 22, 34]);
snOnlySheet.getRange(`A2:A${serviceNowOnly.length + 1}`).format.numberFormat = "@";

const inventoryHeaders = ["Employee Number", "Name", "User Name", "Active Status", "Sys ID", "Updated On", "Present in SAP List"];
snInventorySheet.getRange(`A1:G${usersWithEmployeeNumber.length + 1}`).values = [
  inventoryHeaders,
  ...usersWithEmployeeNumber.map((row) => [row.employeeNumber, row.name, row.userName, row.active ? "Active" : "Inactive", row.sysId, row.updatedOn, sapSet.has(row.employeeNumber) ? "Yes" : "No"]),
];
styleDataSheet(snInventorySheet, inventoryHeaders, usersWithEmployeeNumber.length, [20, 27, 34, 15, 35, 22, 20]);
snInventorySheet.getRange(`A2:A${usersWithEmployeeNumber.length + 1}`).format.numberFormat = "@";
snInventorySheet.getRange(`D2:D${usersWithEmployeeNumber.length + 1}`).conditionalFormats.add("containsText", { text: "Inactive", format: { fill: "#FFF1D6", font: { color: "#805500" } } });

const metrics = [
  ["Metric", "Value", "Definition"],
  ["ServiceNow users total", allUsers.length, "All sys_user records returned from Sandbox"],
  ["ServiceNow users with employee number", usersWithEmployeeNumber.length, "Non-empty sys_user.employee_number"],
  ["ServiceNow users without employee number", allUsers.length - usersWithEmployeeNumber.length, "Empty sys_user.employee_number"],
  ["SAP source rows", sapNumbers.length, "Non-empty rows in employee_numbers.txt"],
  ["Duplicate SAP employee numbers", sapDuplicates.length, "Employee numbers repeated in source file"],
  ["Duplicate ServiceNow employee numbers", snDuplicates.length, "Employee numbers used by more than one sys_user"],
  ["Inactive matched users", inactiveMatches.length, "SAP number matched only to an inactive ServiceNow user"],
  ["Generated at", generatedAt, "Europe/Oslo"],
  ["Source file", sourcePath, "Provided SAP CPI employee-number export"],
  ["ServiceNow instance", instance, "Vår Energi Sandbox"],
];
metricsSheet.getRange(`A1:C${metrics.length}`).values = metrics;
styleDataSheet(metricsSheet, metrics[0], metrics.length - 1, [42, 58, 68]);
metricsSheet.getRange(`B2:C${metrics.length}`).format.wrapText = true;
metricsSheet.getRange(`A2:C${metrics.length}`).format.autofitRows();

await fs.mkdir(outputDir, { recursive: true });

const checks = [];
checks.push((await workbook.inspect({ kind: "table", sheetId: "Summary", range: "A1:F21", include: "values,formulas", tableMaxRows: 25, tableMaxCols: 8, maxChars: 8000 })).ndjson);
checks.push((await workbook.inspect({ kind: "table", sheetId: "Missing in ServiceNow", range: "A1:C12", include: "values,formulas", tableMaxRows: 12, tableMaxCols: 4, maxChars: 4000 })).ndjson);
checks.push((await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 300 }, summary: "final formula error scan" })).ndjson);
await fs.writeFile(path.join(outputDir, "verification.ndjson"), checks.join("\n"), "utf8");

for (const [sheetName, range] of [
  ["Summary", "A1:F21"],
  ["Missing in ServiceNow", "A1:C24"],
  ["Reconciliation", "A1:H20"],
  ["ServiceNow Only", "A1:G20"],
  ["SN With Employee No", "A1:G20"],
  ["Source Metrics", "A1:C11"],
]) {
  const preview = await workbook.render({ sheetName, range, scale: 1.25, format: "png" });
  const safeName = sheetName.replace(/[^A-Za-z0-9]+/g, "_");
  await fs.writeFile(path.join(outputDir, `preview_${safeName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

console.log(JSON.stringify({
  outputPath,
  generatedAt,
  sapNumbers: sapNumbers.length,
  serviceNowUsersTotal: allUsers.length,
  serviceNowWithEmployeeNumber: usersWithEmployeeNumber.length,
  matched: matched.length,
  missing: missing.length,
  matchRate: matched.length / sapNumbers.length,
  serviceNowOnly: serviceNowOnly.length,
  inactiveMatches: inactiveMatches.length,
  sapDuplicates: sapDuplicates.length,
  serviceNowDuplicates: snDuplicates.length,
}, null, 2));
