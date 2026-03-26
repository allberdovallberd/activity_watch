const exportForm = document.getElementById("exportForm");
const exportBtn = document.getElementById("exportBtn");
const exportStatus = document.getElementById("exportStatus");
const mainFilter = document.getElementById("mainFilter");
const subFilter = document.getElementById("subFilter");
const fromDateInput = document.getElementById("fromDateInput");
const toDateInput = document.getElementById("toDateInput");
const fromDateDisplay = document.getElementById("fromDateDisplay");
const toDateDisplay = document.getElementById("toDateDisplay");

initSharedLayout("export");
setDefaultRange();
initAuth(async () => {
  await loadCategories();
  renderMainCategorySelect(mainFilter, false);
  renderSubCategorySelect(subFilter, Number(mainFilter.value), false);
});
document.addEventListener("usage-language-changed", () => {
  syncDateDisplays();
  renderMainCategorySelect(mainFilter, false);
  renderSubCategorySelect(subFilter, Number(mainFilter.value), false);
});

mainFilter.addEventListener("change", () => {
  renderSubCategorySelect(subFilter, mainFilter.value || null, false);
});
fromDateDisplay.addEventListener("click", () => openDatePicker(fromDateInput));
toDateDisplay.addEventListener("click", () => openDatePicker(toDateInput));
fromDateInput.addEventListener("change", onDateInputChanged);
toDateInput.addEventListener("change", onDateInputChanged);

exportForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const mainCategoryId = Number(mainFilter.value || 0);
  const subCategoryId = Number(subFilter.value || 0);
  if (mainCategoryId <= 0 || subCategoryId <= 0) {
    exportStatus.textContent = t("chooseFacultyYear");
    return;
  }
  const fromRaw = fromDateInput.value;
  const toRaw = toDateInput.value;
  if (!fromRaw || !toRaw) {
    exportStatus.textContent = t("chooseValidDateRange");
    return;
  }
  const fromIso = tkDateStartIso(fromRaw);
  const toIso = tkDateEndIso(toRaw);
  exportBtn.disabled = true;
  exportStatus.textContent = t("preparingExport");
  try {
    const payload = await apiGet(
      `/api/v1/export/usage?from=${encodeURIComponent(fromIso)}&to=${encodeURIComponent(toIso)}&main_category_id=${mainCategoryId}&sub_category_id=${subCategoryId}`,
    );
    downloadUsageExport(payload, fromRaw, toRaw);
    exportStatus.textContent = t("exportedDevices", {
      count: payload.devices.length,
    });
  } catch (err) {
    exportStatus.textContent = t("exportFailed", { message: err.message });
  } finally {
    exportBtn.disabled = false;
  }
});

function setDefaultRange() {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const minDate = new Date(today);
  minDate.setDate(today.getDate() - 62);
  const maxValue = toDateInputValue(today);
  const minValue = toDateInputValue(minDate);
  fromDateInput.min = minValue;
  fromDateInput.max = maxValue;
  toDateInput.min = minValue;
  toDateInput.max = maxValue;
  fromDateInput.lang = "en-GB";
  toDateInput.lang = "en-GB";
  fromDateInput.value = maxValue;
  toDateInput.value = maxValue;
  syncDateDisplays();
}

function toDateInputValue(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function tkDateStartIso(dateInputValue) {
  return new Date(`${dateInputValue}T00:00:00+05:00`).toISOString();
}

function tkDateEndIso(dateInputValue) {
  return new Date(`${dateInputValue}T23:59:59.999+05:00`).toISOString();
}

function formatDdMmYyyy(yyyyMmDd) {
  const parts = String(yyyyMmDd).split("-");
  if (parts.length !== 3) {
    return String(yyyyMmDd);
  }
  return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

function syncDateDisplays() {
  fromDateDisplay.value = fromDateInput.value ? formatDdMmYyyy(fromDateInput.value) : "";
  toDateDisplay.value = toDateInput.value ? formatDdMmYyyy(toDateInput.value) : "";
}

function onDateInputChanged() {
  syncDateDisplays();
  if (fromDateInput.value) {
    toDateInput.min = fromDateInput.value;
  }
  if (toDateInput.value) {
    fromDateInput.max = toDateInput.value;
  }
}

function openDatePicker(inputEl) {
  if (!inputEl) {
    return;
  }
  if (typeof inputEl.showPicker === "function") {
    inputEl.showPicker();
    return;
  }
  inputEl.click();
}

function formatAppsList(apps) {
  if (!apps || !apps.length) {
    return "";
  }
  return apps
    .map(
      (app, index) =>
        `${index + 1}. ${escapeHtml(app.app_name || app.package_name || "")} - ${escapeHtml(formatDuration(app.total_foreground_ms || 0))}`,
    )
    .join("<br/>");
}

function sanitizeFilePart(value) {
  return String(value || "")
    .trim()
    .replace(/[\\/:*?"<>|]+/g, "-")
    .replace(/\s+/g, "_");
}

function xmlEscape(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function toDosDateTime(date = new Date()) {
  const year = Math.max(1980, date.getFullYear());
  const dosTime =
    ((date.getHours() & 0x1f) << 11)
    | ((date.getMinutes() & 0x3f) << 5)
    | Math.floor(date.getSeconds() / 2);
  const dosDate =
    (((year - 1980) & 0x7f) << 9)
    | (((date.getMonth() + 1) & 0x0f) << 5)
    | (date.getDate() & 0x1f);
  return { dosTime, dosDate };
}

function makeCrc32Table() {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let j = 0; j < 8; j += 1) {
      c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c >>> 0;
  }
  return table;
}

const CRC32_TABLE = makeCrc32Table();

function crc32(bytes) {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i += 1) {
    crc = CRC32_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function uint16LE(value) {
  return Uint8Array.of(value & 0xff, (value >>> 8) & 0xff);
}

function uint32LE(value) {
  return Uint8Array.of(
    value & 0xff,
    (value >>> 8) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 24) & 0xff,
  );
}

function concatUint8Arrays(parts) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const merged = new Uint8Array(total);
  let offset = 0;
  parts.forEach((part) => {
    merged.set(part, offset);
    offset += part.length;
  });
  return merged;
}

function createStoredZip(files) {
  const encoder = new TextEncoder();
  const now = toDosDateTime(new Date());
  const localParts = [];
  const centralParts = [];
  let offset = 0;

  files.forEach((file) => {
    const fileNameBytes = encoder.encode(file.name);
    const dataBytes = typeof file.content === "string" ? encoder.encode(file.content) : file.content;
    const crc = crc32(dataBytes);

    const localHeader = concatUint8Arrays([
      uint32LE(0x04034b50),
      uint16LE(20),
      uint16LE(0),
      uint16LE(0),
      uint16LE(now.dosTime),
      uint16LE(now.dosDate),
      uint32LE(crc),
      uint32LE(dataBytes.length),
      uint32LE(dataBytes.length),
      uint16LE(fileNameBytes.length),
      uint16LE(0),
      fileNameBytes,
      dataBytes,
    ]);
    localParts.push(localHeader);

    const centralHeader = concatUint8Arrays([
      uint32LE(0x02014b50),
      uint16LE(20),
      uint16LE(20),
      uint16LE(0),
      uint16LE(0),
      uint16LE(now.dosTime),
      uint16LE(now.dosDate),
      uint32LE(crc),
      uint32LE(dataBytes.length),
      uint32LE(dataBytes.length),
      uint16LE(fileNameBytes.length),
      uint16LE(0),
      uint16LE(0),
      uint16LE(0),
      uint16LE(0),
      uint32LE(0),
      uint32LE(offset),
      fileNameBytes,
    ]);
    centralParts.push(centralHeader);
    offset += localHeader.length;
  });

  const centralDirectory = concatUint8Arrays(centralParts);
  const localDirectory = concatUint8Arrays(localParts);
  const endRecord = concatUint8Arrays([
    uint32LE(0x06054b50),
    uint16LE(0),
    uint16LE(0),
    uint16LE(files.length),
    uint16LE(files.length),
    uint32LE(centralDirectory.length),
    uint32LE(localDirectory.length),
    uint16LE(0),
  ]);
  return concatUint8Arrays([localDirectory, centralDirectory, endRecord]);
}

function sheetCell(ref, value, styleIndex = 0) {
  const styleAttr = styleIndex ? ` s="${styleIndex}"` : "";
  return `<c r="${ref}" t="inlineStr"${styleAttr}><is><t xml:space="preserve">${xmlEscape(value)}</t></is></c>`;
}

function buildWorksheetXml(payload, fromRaw, toRaw) {
  const title = `${formatDdMmYyyy(fromRaw)} bilen ${formatDdMmYyyy(toRaw)} aralygynda ${payload.main_category_name} fakultetiniň ${payload.sub_category_name} ýyl talyplarynyň enjam ulanyş maglumatlary`;
  const rows = [];
  rows.push(`<row r="1" ht="28" customHeight="1">${sheetCell("A1", title, 1)}</row>`);
  rows.push(
    `<row r="2">${
      sheetCell("A2", "Enjam ID", 1)
      + sheetCell("B2", "Jemi ekran wagty", 1)
      + sheetCell("C2", "Soňky gezek görüldi", 1)
      + sheetCell("D2", "Iň köp ulanylan programmalar", 1)
    }</row>`,
  );
  (payload.devices || []).forEach((device, index) => {
    const rowNumber = index + 3;
    const appsText = (device.most_used_apps || [])
      .map((app, appIndex) => `${appIndex + 1}. ${app.app_name || app.package_name || ""} - ${formatDuration(app.total_foreground_ms || 0)}`)
      .join("\n");
    rows.push(
      `<row r="${rowNumber}">${
        sheetCell(`A${rowNumber}`, device.device_id || "")
        + sheetCell(`B${rowNumber}`, formatDuration(device.total_foreground_ms || 0))
        + sheetCell(`C${rowNumber}`, formatTurkmenTime(device.last_seen_at))
        + sheetCell(`D${rowNumber}`, appsText, 2)
      }</row>`,
    );
  });
  if (!(payload.devices || []).length) {
    rows.push(`<row r="3">${sheetCell("A3", "Saýlanan eksport sazlamalary boýunça enjam tapylmady.")}</row>`);
  }
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <dimension ref="A1:D${Math.max((payload.devices || []).length + 2, 3)}"/>
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <cols>
    <col min="1" max="1" width="18" customWidth="1"/>
    <col min="2" max="2" width="18" customWidth="1"/>
    <col min="3" max="3" width="24" customWidth="1"/>
    <col min="4" max="4" width="56" customWidth="1"/>
  </cols>
  <sheetData>
    ${rows.join("")}
  </sheetData>
  <mergeCells count="1"><mergeCell ref="A1:D1"/></mergeCells>
</worksheet>`;
}

function buildWorkbookFiles(payload, fromRaw, toRaw) {
  const worksheetXml = buildWorksheetXml(payload, fromRaw, toRaw);
  return [
    {
      name: "[Content_Types].xml",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>`,
    },
    {
      name: "_rels/.rels",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`,
    },
    {
      name: "xl/workbook.xml",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Ulanyş eksporty" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>`,
    },
    {
      name: "xl/_rels/workbook.xml.rels",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>`,
    },
    {
      name: "xl/styles.xml",
      content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/><family val="2"/></font>
    <font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>
  </fonts>
  <fills count="2">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1">
      <alignment vertical="top"/>
    </xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1">
      <alignment vertical="top"/>
    </xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1">
      <alignment vertical="top" wrapText="1"/>
    </xf>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>`,
    },
    {
      name: "xl/worksheets/sheet1.xml",
      content: worksheetXml,
    },
  ];
}

function downloadUsageExport(payload, fromRaw, toRaw) {
  const files = buildWorkbookFiles(payload, fromRaw, toRaw);
  const zipBytes = createStoredZip(files);
  const blob = new Blob(
    [zipBytes],
    { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
  );
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  const fileName = `ulanysh_export_${sanitizeFilePart(payload.main_category_name)}_${sanitizeFilePart(payload.sub_category_name)}_${fromRaw}_${toRaw}.xlsx`;
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
