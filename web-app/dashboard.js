const state = {
  allDevices: [],
  page: 1,
  selectedDeviceId: null,
  selectedRowRef: null,
  lastDevicesHash: "",
  lastDetailsKey: "",
  lastAppsHash: "",
  lastSummaryHash: "",
  lastApps: [],
  selectedDeviceIds: new Set(),
  lastPageItems: [],
  userActiveUntil: 0,
};
const DEVICES_PAGE_SIZE = 50;

const searchInput = document.getElementById("searchInput");
const mainFilter = document.getElementById("mainFilter");
const subFilter = document.getElementById("subFilter");
const devicesBody = document.getElementById("devicesBody");
const paginationWrap = document.getElementById("paginationWrap");
const selectAllDashboardDevices = document.getElementById("selectAllDashboardDevices");
const devicesCount = document.getElementById("devicesCount");
const selectionBar = document.getElementById("selectionBar");
const selectionBarText = document.getElementById("selectionBarText");

const selectedDeviceWrap = document.getElementById("selectedDeviceWrap");
const selectedDeviceLabel = document.getElementById("selectedDeviceLabel");
const noDeviceSelected = document.getElementById("noDeviceSelected");
const fromDateInput = document.getElementById("fromDateInput");
const toDateInput = document.getElementById("toDateInput");
const fromDateDisplay = document.getElementById("fromDateDisplay");
const toDateDisplay = document.getElementById("toDateDisplay");
const detailsStatus = document.getElementById("detailsStatus");
const appsBody = document.getElementById("appsBody");
const appsCount = document.getElementById("appsCount");
const includeSystemApps = document.getElementById("includeSystemApps");
const appSearchInput = document.getElementById("appSearchInput");
const dailyUsageBody = document.getElementById("dailyUsageBody");
const screenTimeValue = document.getElementById("screenTimeValue");
const screenTimeRange = document.getElementById("screenTimeRange");
const usageChartBody = document.getElementById("usageChartBody");
const usageChartEmpty = document.getElementById("usageChartEmpty");

initSharedLayout("dashboard");
setDefaultRange();
initAuth(async () => {
  await loadCategories();
  renderMainCategorySelect(mainFilter, true);
  renderSubCategorySelect(subFilter, null, true);
  await loadDevices();
  setInterval(async () => {
    if (!appState.adminToken) {
      return;
    }
    if (!shouldAutoRefresh()) {
      return;
    }
    await loadDevices(false, { preserveScroll: true, silent: true });
    if (state.selectedDeviceId) {
      await loadSelectedDeviceDetails({ silent: true, preserveScroll: true });
    }
  }, 5000);
});
document.addEventListener("usage-language-changed", () => {
  syncDateDisplays();
  renderMainCategorySelect(mainFilter, true);
  renderSubCategorySelect(subFilter, mainFilter.value || null, true);
  renderDevices(state.page || 1);
  renderApps(state.lastApps || []);
  if (state.selectedDeviceId) {
    selectedDeviceLabel.textContent = `${t("deviceDetails")}: ${state.selectedDeviceId}`;
    loadSelectedDeviceDetails({ silent: true, preserveScroll: true });
  }
});

bindUserActivityGuards();

searchInput.addEventListener("input", () => renderDevices(1));
mainFilter.addEventListener("change", () => {
  renderSubCategorySelect(subFilter, mainFilter.value || null, true);
  renderDevices(1);
});
subFilter.addEventListener("change", () => renderDevices(1));
fromDateDisplay.addEventListener("click", () => openDatePicker(fromDateInput));
toDateDisplay.addEventListener("click", () => openDatePicker(toDateInput));
fromDateInput.addEventListener("change", onDateInputChanged);
toDateInput.addEventListener("change", onDateInputChanged);
if (includeSystemApps) {
  includeSystemApps.addEventListener("change", () => {
    renderApps(state.lastApps || []);
    if (state.selectedDeviceId) {
      loadSelectedDeviceDetails({ silent: true, preserveScroll: true });
    }
  });
}
if (appSearchInput) {
  appSearchInput.addEventListener("input", () => {
    renderApps(state.lastApps || []);
  });
}
if (selectAllDashboardDevices) {
  selectAllDashboardDevices.addEventListener("change", () => {
    hideContextMenu();
    const shouldSelect = selectAllDashboardDevices.checked;
    (state.lastPageItems || []).forEach((d) => {
      const deviceId = d.device_id;
      if (shouldSelect) {
        state.selectedDeviceIds.add(deviceId);
      } else {
        state.selectedDeviceIds.delete(deviceId);
      }
    });
    devicesBody.querySelectorAll("tr").forEach((row) => {
      const checkbox = row.querySelector("input.row-check");
      if (!checkbox) {
        return;
      }
      checkbox.checked = shouldSelect;
      row.classList.toggle("checked-row", shouldSelect);
    });
    selectAllDashboardDevices.indeterminate = false;
    updateSelectionBar();
  });
}

async function loadDevices(resetPage = true, options = {}) {
  const resp = await apiGet("/api/v1/devices");
  const devices = resp.devices || [];
  const nextHash = JSON.stringify(devices);
  if (!resetPage && state.lastDevicesHash === nextHash) {
    return;
  }
  const preserveScroll = !!options.preserveScroll;
  const prevScroll = preserveScroll ? window.scrollY : null;
  state.allDevices = devices;
  state.lastDevicesHash = nextHash;
  renderDevices(resetPage ? 1 : state.page);
  if (!resetPage && preserveScroll && prevScroll != null) {
    requestAnimationFrame(() => {
      window.scrollTo({ top: prevScroll });
    });
  }
}

function renderDevices(page) {
  const search = searchInput.value.trim().toUpperCase();
  const mainId = mainFilter.value ? Number(mainFilter.value) : null;
  const subId = subFilter.value ? Number(subFilter.value) : null;
  const filtered = state.allDevices
    .filter((d) => {
      if (search && !String(d.device_id || "").toUpperCase().includes(search)) {
        return false;
      }
      if (mainId && d.main_category_id !== mainId) {
        return false;
      }
      if (subId && d.sub_category_id !== subId) {
        return false;
      }
      return true;
    })
    .sort((a, b) => {
      const aTime = a.last_seen_at ? new Date(a.last_seen_at).getTime() : 0;
      const bTime = b.last_seen_at ? new Date(b.last_seen_at).getTime() : 0;
      return bTime - aTime;
    });

  const pg = paginate(filtered, page, DEVICES_PAGE_SIZE);
  state.page = pg.page;
  state.lastPageItems = pg.items;
  if (devicesCount) {
    devicesCount.innerHTML = tRich("devicesCount", {
      shown: pg.items.length,
      total: filtered.length,
    }, ["shown", "total"]);
  }
  if (!pg.items.length) {
    devicesBody.innerHTML = `<tr><td colspan="7">${escapeHtml(t("noDevicesFound"))}</td></tr>`;
    updateDashboardSelectAllState([]);
  } else {
    devicesBody.innerHTML = "";
    pg.items.forEach((d) => {
      const isChecked = state.selectedDeviceIds.has(d.device_id);
      const tr = document.createElement("tr");
      if (isChecked) {
        tr.classList.add("checked-row");
      }
      tr.innerHTML = `
        <td class="table-checkbox">
          <input class="row-check" type="checkbox" ${isChecked ? "checked" : ""} aria-label="${escapeHtml(t("deviceId"))} ${escapeHtml(d.device_id)}" />
        </td>
        <td>${escapeHtml(d.device_id)}</td>
        <td>${escapeHtml(d.display_name || "")}</td>
        <td>${escapeHtml(d.main_category_name || "")}</td>
        <td>${escapeHtml(d.sub_category_name || "")}</td>
        <td>${escapeHtml(formatTurkmenTime(d.last_seen_at))}</td>
        <td class="conn-col">${renderConnectionIcon(!!d.is_connected)}</td>
      `;
      const checkbox = tr.querySelector(".row-check");
      if (checkbox) {
        checkbox.addEventListener("click", (event) => {
          event.stopPropagation();
          hideContextMenu();
          toggleDashboardSelection(d.device_id, checkbox.checked, tr);
          updateDashboardSelectAllState(pg.items);
        });
      }
      tr.addEventListener("click", () => {
        selectDevice(d.device_id, tr);
      });
      devicesBody.appendChild(tr);
    });
    updateDashboardSelectAllState(pg.items);
  }
  updateSelectionBar();
  renderPagination(paginationWrap, pg.page, pg.totalPages, renderDevices);
}

function toggleDashboardSelection(deviceId, isChecked, rowEl) {
  if (isChecked) {
    state.selectedDeviceIds.add(deviceId);
  } else {
    state.selectedDeviceIds.delete(deviceId);
  }
  if (rowEl) {
    rowEl.classList.toggle("checked-row", isChecked);
  }
  updateSelectionBar();
}

function updateDashboardSelectAllState(items) {
  if (!selectAllDashboardDevices) {
    return;
  }
  const visible = items || [];
  if (!visible.length) {
    selectAllDashboardDevices.checked = false;
    selectAllDashboardDevices.indeterminate = false;
    return;
  }
  let selectedCount = 0;
  visible.forEach((d) => {
    if (state.selectedDeviceIds.has(d.device_id)) {
      selectedCount += 1;
    }
  });
  if (selectedCount === 0) {
    selectAllDashboardDevices.checked = false;
    selectAllDashboardDevices.indeterminate = false;
  } else if (selectedCount === visible.length) {
    selectAllDashboardDevices.checked = true;
    selectAllDashboardDevices.indeterminate = false;
  } else {
    selectAllDashboardDevices.checked = false;
    selectAllDashboardDevices.indeterminate = true;
  }
}

function updateSelectionBar() {
  if (!selectionBar || !selectionBarText) {
    return;
  }
  const count = state.selectedDeviceIds.size;
  if (!count) {
    selectionBar.classList.add("hidden");
    selectionBarText.textContent = t("deviceSelectionCount", { count: 0 });
    return;
  }
  selectionBar.classList.remove("hidden");
  selectionBarText.textContent = t("deviceSelectionCount", { count });
}

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
  if (fromDateDisplay) {
    fromDateDisplay.value = fromDateInput.value ? formatDdMmYyyy(fromDateInput.value) : "";
  }
  if (toDateDisplay) {
    toDateDisplay.value = toDateInput.value ? formatDdMmYyyy(toDateInput.value) : "";
  }
}

function onDateInputChanged() {
  syncDateDisplays();
  if (fromDateInput.value) {
    toDateInput.min = fromDateInput.value;
  }
  if (toDateInput.value) {
    fromDateInput.max = toDateInput.value;
  }
  if (state.selectedDeviceId) {
    loadSelectedDeviceDetails({ silent: false, preserveScroll: true });
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

// formatTurkmenTime is provided by common.js

function selectDevice(deviceId, rowEl) {
  state.selectedDeviceId = deviceId;
  selectedDeviceLabel.textContent = `${t("deviceDetails")}: ${deviceId}`;
  selectedDeviceWrap.classList.remove("hidden");
  noDeviceSelected.classList.add("hidden");
  detailsStatus.textContent = "";
  if (state.selectedRowRef) {
    state.selectedRowRef.classList.remove("selected-row");
  }
  state.selectedRowRef = rowEl;
  rowEl.classList.add("selected-row");
  loadSelectedDeviceDetails();
}

function clearSelectedDevice() {
  state.selectedDeviceId = null;
  if (selectedDeviceWrap) {
    selectedDeviceWrap.classList.add("hidden");
  }
  if (noDeviceSelected) {
    noDeviceSelected.classList.remove("hidden");
  }
  if (detailsStatus) {
    detailsStatus.textContent = "";
  }
  if (state.selectedRowRef) {
    state.selectedRowRef.classList.remove("selected-row");
    state.selectedRowRef = null;
  }
}

async function loadSelectedDeviceDetails(options = {}) {
  const deviceId = state.selectedDeviceId;
  if (!deviceId) {
    return;
  }
  const silent = !!options.silent;
  const preserveScroll = !!options.preserveScroll;
  const prevScroll = preserveScroll ? window.scrollY : null;
  const fromRaw = fromDateInput.value;
  const toRaw = toDateInput.value;
  if (!fromRaw || !toRaw) {
    detailsStatus.textContent = t("chooseValidDateRange");
    return;
  }
  const fromDateStart = new Date(`${fromRaw}T00:00:00+05:00`);
  const toDateEnd = new Date(`${toRaw}T23:59:59.999+05:00`);
  const todayEnd = new Date();
  todayEnd.setHours(23, 59, 59, 999);
  const minFrom = new Date(todayEnd);
  minFrom.setDate(minFrom.getDate() - 62);
  minFrom.setHours(0, 0, 0, 0);
  if (fromDateStart > toDateEnd) {
    detailsStatus.textContent = t("chooseValidDateRange");
    return;
  }
  if (toDateEnd > todayEnd) {
    detailsStatus.textContent = t("chooseValidDateRange");
    return;
  }
  if (fromDateStart < minFrom) {
    detailsStatus.textContent = t("maxRange");
    return;
  }
  const maxRangeMs = 62 * 24 * 60 * 60 * 1000;
  if (toDateEnd.getTime() - fromDateStart.getTime() > maxRangeMs) {
    detailsStatus.textContent = t("maxRange");
    return;
  }
  const from = tkDateStartIso(fromRaw);
  const to = tkDateEndIso(toRaw);
  if (!silent) {
    detailsStatus.textContent = t("loadingDetails");
    appsBody.innerHTML = "";
  }

  try {
    const includeSystem = includeSystemApps ? includeSystemApps.checked : false;
    const includeParam = `include_system=${includeSystem ? "true" : "false"}`;
    const [appsData, dailyData] = await Promise.all([
      apiGet(
        `/api/v1/devices/${encodeURIComponent(deviceId)}/apps?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
      ),
      apiGet(
        `/api/v1/devices/${encodeURIComponent(deviceId)}/screen-time?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}&${includeParam}`,
      ),
    ]);
    const apps = appsData.apps || [];
    const appsHash = JSON.stringify(apps);
    const totalMs = (dailyData.days || []).reduce(
      (sum, row) => sum + (row.total_foreground_ms || 0),
      0,
    );
    const rangeLabel = describeRange(fromRaw, toRaw);
    const summaryHash = JSON.stringify([totalMs, rangeLabel, includeSystem]);
    const detailsKey = `${deviceId}|${from}|${to}|sys:${includeSystem ? "1" : "0"}`;
    if (!silent || detailsKey !== state.lastDetailsKey || appsHash !== state.lastAppsHash) {
      state.lastApps = apps;
      renderApps(apps);
      renderUsageChart(apps);
      renderDailyUsage(dailyData.days || [], fromRaw, toRaw);
      state.lastAppsHash = appsHash;
      state.lastDetailsKey = detailsKey;
    }
    if (screenTimeValue) {
      screenTimeValue.textContent = formatDuration(totalMs);
    }
    if (screenTimeRange) {
      screenTimeRange.textContent = rangeLabel;
    }
    if (!silent || summaryHash !== state.lastSummaryHash) {
      detailsStatus.textContent = "";
      state.lastSummaryHash = summaryHash;
    }
  } catch (err) {
    detailsStatus.textContent = t("loadFailed", { message: err.message });
  }

  if (preserveScroll && prevScroll != null) {
    requestAnimationFrame(() => {
      window.scrollTo({ top: prevScroll });
    });
  }
}

const SYSTEM_PACKAGE_PREFIXES = [
  "android",
  "com.android.systemui",
  "com.android.settings",
  "com.android.launcher",
  "com.android.launcher3",
  "com.android.storagemanager",
  "com.android.permissioncontroller",
  "com.android.packageinstaller",
  "com.android.providers.",
  "com.android.inputmethod",
  "com.android.shell",
  "com.android.phone",
  "com.android.server.telecom",
  "com.android.bluetooth",
  "com.android.nfc",
  "com.android.cellbroadcast",
  "com.android.printspooler",
  "com.android.managedprovisioning",
  "com.android.calendar",
  "com.android.contacts",
  "com.google.android.gsf",
  "com.google.android.syncadapters.",
  "com.google.android.setupwizard",
  "com.google.android.apps.wellbeing",
  "com.topjohnwu.magisk",
  "com.mediatek.",
];

const SYSTEM_NAME_KEYWORDS = [
  "settings",
  "system ui",
  "android system",
  "launcher",
  "android setup",
  "setup wizard",
  "restore",
  "permission controller",
  "package installer",
  "input method",
  "print spooler",
  "carrier services",
  "telecom",
  "sim toolkit",
  "downloads",
  "storage",
  "sync",
  "framework",
  "gms policy",
  "google gms policy",
  "policy",
  "mediatek",
  "digital wellbeing",
  "headwind mdm",
  "mdm agent",
  "musicfx",
  "phone services",
  "root explorer",
  "magisk",
];

const USER_FACING_PACKAGE_PREFIXES = [
  "com.android.chrome",
  "com.android.browser",
  "com.android.gallery",
  "com.android.calculator",
  "com.android.music",
  "com.android.email",
  "com.android.dialer",
  "com.android.camera",
  "com.android.fmradio",
  "com.android.vending",
  "com.google.android.apps.",
  "com.google.android.youtube",
  "com.google.android.calendar",
  "com.google.android.contacts",
  "com.google.android.gm",
  "com.google.android.music",
  "com.google.android.videos",
  "com.google.android.apps.photos",
  "com.google.android.apps.maps",
  "com.google.android.apps.nbu",
  "com.google.android.apps.messaging",
  "com.google.android.play.games",
];

const USER_FACING_NAME_KEYWORDS = [
  "chrome",
  "browser",
  "music",
  "gallery",
  "photos",
  "calculator",
  "camera",
  "radio",
  "fm radio",
  "movies",
  "video",
  "youtube",
  "maps",
  "gmail",
  "email",
  "drive",
  "calendar",
  "clock",
  "contacts",
  "messages",
  "messaging",
  "play games",
  "play store",
  "files",
  "recorder",
];

const SYSTEM_STYLE_NAME_KEYWORDS = [
  "storage",
  "sync",
  "framework",
  "policy",
  "setup",
  "service",
  "services",
  "wellbeing",
  "musicfx",
];

function includesAnyKeyword(value, keywords) {
  return keywords.some((keyword) => value.includes(keyword));
}

function startsWithAnyPrefix(value, prefixes) {
  return prefixes.some((prefix) => value === prefix || value.startsWith(`${prefix}.`) || value.startsWith(prefix));
}

function isUserFacingPreinstalledApp(app) {
  const packageName = String(app.package_name || "").toLowerCase();
  const appName = String(app.app_name || "").toLowerCase();
  if (startsWithAnyPrefix(packageName, USER_FACING_PACKAGE_PREFIXES)) {
    return true;
  }
  if (includesAnyKeyword(appName, SYSTEM_STYLE_NAME_KEYWORDS)) {
    return false;
  }
  return (
    includesAnyKeyword(appName, USER_FACING_NAME_KEYWORDS)
  );
}

function isCoreSystemApp(app) {
  const packageName = String(app.package_name || "").toLowerCase();
  const appName = String(app.app_name || "").toLowerCase();
  return (
    startsWithAnyPrefix(packageName, SYSTEM_PACKAGE_PREFIXES) ||
    includesAnyKeyword(appName, SYSTEM_NAME_KEYWORDS)
  );
}

function isSystemApp(app) {
  if (isCoreSystemApp(app)) {
    return true;
  }
  if (isUserFacingPreinstalledApp(app)) {
    return false;
  }
  return !!app.is_system;
}

function getFilteredApps(apps) {
  const showSystem = includeSystemApps ? includeSystemApps.checked : false;
  const search = String(appSearchInput?.value || "").trim().toLowerCase();
  return (apps || []).filter((app) => {
    if (app.is_tracking) {
      return false;
    }
    if (!showSystem && isSystemApp(app)) {
      return false;
    }
    if (search) {
      const appName = String(app.app_name || "").toLowerCase();
      const packageName = String(app.package_name || "").toLowerCase();
      if (!appName.includes(search) && !packageName.includes(search)) {
        return false;
      }
    }
    return true;
  });
}

function renderApps(apps) {
  const filtered = getFilteredApps(apps);
  if (appsCount) {
    appsCount.innerHTML = tRich("appsCount", {
      shown: filtered.length,
      total: (apps || []).length,
    }, ["shown", "total"]);
  }
  if (!filtered.length) {
    appsBody.innerHTML = `<tr><td colspan="4">${escapeHtml(t("noAppsFound"))}</td></tr>`;
    return;
  }
  appsBody.innerHTML = "";
  filtered.forEach((app) => {
    const tr = document.createElement("tr");
    const iconHtml = app.icon_base64
      ? `<img class="app-icon" src="data:image/*;base64,${app.icon_base64}" alt="icon" />`
      : `<span class="app-icon app-icon-fallback">-</span>`;
    const systemBadge = isSystemApp(app)
      ? ` <span class="app-badge system-app-badge">${escapeHtml(t("systemAppBadge"))}</span>`
      : "";
    tr.innerHTML = `
      <td>${iconHtml}</td>
      <td>${escapeHtml(app.app_name || "")}${systemBadge}</td>
      <td>${escapeHtml(app.package_name || "")}</td>
      <td>${formatDuration(app.total_foreground_ms || 0)}</td>
    `;
    appsBody.appendChild(tr);
  });
}

function renderUsageChart(apps) {
  if (!usageChartBody || !usageChartEmpty) {
    return;
  }
  const filtered = getFilteredApps(apps).filter((app) => (app.total_foreground_ms || 0) >= 60 * 1000);
  if (!filtered.length) {
    usageChartBody.classList.add("hidden");
    usageChartEmpty.classList.remove("hidden");
    usageChartEmpty.textContent = t("noAppUsageYet");
    usageChartBody.innerHTML = "";
    return;
  }
  const sorted = [...filtered].sort(
    (a, b) => (b.total_foreground_ms || 0) - (a.total_foreground_ms || 0),
  );
  const maxItems = 10;
  const topItems = sorted.slice(0, maxItems);
  const remaining = sorted.slice(maxItems);
  if (remaining.length) {
    const otherTotal = remaining.reduce(
      (sum, app) => sum + (app.total_foreground_ms || 0),
      0,
    );
    topItems.push({
      app_name: t("all"),
      package_name: "other",
      total_foreground_ms: otherTotal,
    });
  }
  const maxMs = Math.max(...topItems.map((app) => app.total_foreground_ms || 0), 1);
  usageChartBody.innerHTML = "";
  topItems.forEach((app) => {
    const name = app.app_name || app.package_name || t("app");
    const totalMs = app.total_foreground_ms || 0;
    const percentage = Math.max(2, Math.round((totalMs / maxMs) * 100));
    const valueLabel = formatDuration(totalMs);
    const bar = document.createElement("div");
    bar.className = "usage-bar";
    bar.title = `${name} — ${valueLabel}`;
    bar.innerHTML = `<div class="usage-bar-fill" style="height: ${percentage}%"></div>`;
    usageChartBody.appendChild(bar);
  });
  usageChartEmpty.classList.add("hidden");
  usageChartBody.classList.remove("hidden");
}

function renderDailyUsage(screenDays, fromRaw = "", toRaw = "") {
  if (!dailyUsageBody) {
    return;
  }
  const rows = (screenDays || [])
    .map((row) => {
      const dayKey = String(row.day || "").slice(0, 10);
      return {
        day: dayKey,
        total_foreground_ms: row.total_foreground_ms || 0,
      };
    })
    .filter((row) => {
      if (!row.day) {
        return false;
      }
      if (fromRaw && row.day < fromRaw) {
        return false;
      }
      if (toRaw && row.day > toRaw) {
        return false;
      }
      return true;
    });
  if (!rows.length) {
    dailyUsageBody.innerHTML = `<tr><td colspan="2">${escapeHtml(t("noDailyUsage"))}</td></tr>`;
    return;
  }
  dailyUsageBody.innerHTML = "";
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(formatDdMmYyyy(row.day))}</td>
      <td>${formatDuration(row.total_foreground_ms)}</td>
    `;
    dailyUsageBody.appendChild(tr);
  });
}

function describeRange(fromRaw, toRaw) {
  if (!fromRaw || !toRaw) {
    return "";
  }
  if (fromRaw === toRaw) {
    return t("todayRange");
  }
  return t("rangeLabel", { from: formatDdMmYyyy(fromRaw), to: formatDdMmYyyy(toRaw) });
}


function bindUserActivityGuards() {
  const markActive = () => {
    state.userActiveUntil = Date.now() + 2500;
  };
  window.addEventListener("scroll", markActive, { passive: true });
  window.addEventListener("wheel", markActive, { passive: true });
  window.addEventListener("pointerdown", markActive);
  window.addEventListener("keydown", markActive);
}

function shouldAutoRefresh() {
  return Date.now() > state.userActiveUntil;
}
