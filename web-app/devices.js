const state = {
  allDevices: [],
  page: 1,
  lastDevicesHash: "",
  selectedDeviceIds: new Set(),
  lastPageItems: [],
  userActiveUntil: 0,
};
const DEVICES_PAGE_SIZE = 50;

const deviceForm = document.getElementById("deviceForm");
const deviceIdInput = document.getElementById("deviceIdInput");
const deviceMainSelect = document.getElementById("deviceMainSelect");
const deviceSubSelect = document.getElementById("deviceSubSelect");
const deviceSubmitBtn = document.getElementById("deviceSubmitBtn");
const deviceStatus = document.getElementById("deviceStatus");

const searchInput = document.getElementById("searchInput");
const mainFilter = document.getElementById("mainFilter");
const subFilter = document.getElementById("subFilter");
const devicesBody = document.getElementById("devicesBody");
const paginationWrap = document.getElementById("paginationWrap");
const selectAllDevices = document.getElementById("selectAllDevices");
const devicesListStatus = document.getElementById("devicesListStatus");
const devicesCount = document.getElementById("devicesCount");
const selectionBar = document.getElementById("selectionBar");
const selectionBarText = document.getElementById("selectionBarText");

initSharedLayout("devices");
initAuth(async () => {
  await loadCategories();
  renderMainCategorySelect(deviceMainSelect, false);
  renderSubCategorySelect(deviceSubSelect, Number(deviceMainSelect.value), false);
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
    await loadDevices(false, { preserveScroll: true });
  }, 5000);
});
document.addEventListener("usage-language-changed", () => {
  renderMainCategorySelect(deviceMainSelect, false);
  renderSubCategorySelect(deviceSubSelect, Number(deviceMainSelect.value), false);
  renderMainCategorySelect(mainFilter, true);
  renderSubCategorySelect(subFilter, mainFilter.value || null, true);
  refreshDeviceModalTexts();
  refreshBulkEditModalTexts();
  renderDevices(state.page || 1);
  updateSelectionBar();
});

bindUserActivityGuards();

deviceMainSelect.addEventListener("change", () => {
  renderSubCategorySelect(deviceSubSelect, Number(deviceMainSelect.value), false);
});
mainFilter.addEventListener("change", () => {
  renderSubCategorySelect(subFilter, mainFilter.value || null, true);
  renderDevices(1);
});
subFilter.addEventListener("change", () => renderDevices(1));
searchInput.addEventListener("input", () => renderDevices(1));
if (selectAllDevices) {
  selectAllDevices.addEventListener("change", () => {
    hideContextMenu();
    const shouldSelect = selectAllDevices.checked;
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
    selectAllDevices.indeterminate = false;
    updateSelectionBar();
  });
}
devicesBody.addEventListener("contextmenu", (event) => {
  if (!state.selectedDeviceIds.size) {
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  const selectedIds = Array.from(state.selectedDeviceIds);
  showContextMenu(event.clientX, event.clientY, [
    {
      label: t("editSelectedDevicesAction", { count: selectedIds.length }),
      onClick: () => {
        if (selectedIds.length === 1) {
          const device = state.allDevices.find((d) => d.device_id === selectedIds[0]);
          if (device) {
            openDeviceEditModal(device);
            return;
          }
        }
        openBulkEditModal(selectedIds);
      },
    },
    {
      label: t("deleteSelectedDevicesAction", { count: selectedIds.length }),
      onClick: () => bulkDeleteDevices(selectedIds),
    },
  ]);
});

deviceForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const payload = {
    device_id: deviceIdInput.value.trim().toUpperCase(),
    main_category_id: Number(deviceMainSelect.value),
    sub_category_id: Number(deviceSubSelect.value),
  };
  deviceStatus.textContent = t("creating");
  try {
    await apiPost("/api/v1/devices", payload);
    deviceStatus.textContent = t("deviceCreated");
    deviceForm.reset();
    renderMainCategorySelect(deviceMainSelect, false);
    renderSubCategorySelect(deviceSubSelect, Number(deviceMainSelect.value), false);
    await loadDevices();
  } catch (err) {
    deviceStatus.textContent = t("failed", { message: err.message });
  }
});

async function loadDevices(resetPage = true, options = {}) {
  const data = await apiGet("/api/v1/devices");
  const devices = data.devices || [];
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
  const filtered = state.allDevices.filter((d) => {
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
    devicesBody.innerHTML = `<tr><td colspan="8">${escapeHtml(t("noDevicesFound"))}</td></tr>`;
    updateDevicesSelectAllState([]);
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
        <td class="actions-col">
          <button type="button" class="edit-btn">${escapeHtml(t("edit"))}</button>
          <button type="button" class="danger delete-btn">${escapeHtml(t("delete"))}</button>
        </td>
      `;
      const checkbox = tr.querySelector(".row-check");
      if (checkbox) {
        checkbox.addEventListener("click", (event) => {
          event.stopPropagation();
          hideContextMenu();
          toggleDevicesSelection(d.device_id, checkbox.checked, tr);
          updateDevicesSelectAllState(pg.items);
        });
      }
      tr.querySelector(".edit-btn").addEventListener("click", () => openDeviceEditModal(d));
      tr.querySelector(".delete-btn").addEventListener("click", async () => {
        const ok = await confirmDialog(t("deleteDeviceConfirm", { deviceId: d.device_id }), t("delete"), t("cancel"));
        if (!ok) {
          return;
        }
        try {
          await apiDelete(`/api/v1/devices/${encodeURIComponent(d.device_id)}`);
          await loadDevices();
        } catch (err) {
          deviceStatus.textContent = t("deleteFailed", { message: err.message });
        }
      });
      devicesBody.appendChild(tr);
    });
    updateDevicesSelectAllState(pg.items);
  }
  updateSelectionBar();
  renderPagination(paginationWrap, pg.page, pg.totalPages, renderDevices);
}

async function bulkDeleteDevices(deviceIds) {
  if (!deviceIds.length) {
    return;
  }
  const ok = await confirmDialog(
    t("deleteSelectedDevicesConfirm", { count: deviceIds.length }),
    t("delete"),
    t("cancel"),
  );
  if (!ok) {
    return;
  }
  if (devicesListStatus) {
    devicesListStatus.textContent = t("deleting");
  }
  const failures = [];
  for (const deviceId of deviceIds) {
    try {
      await apiDelete(`/api/v1/devices/${encodeURIComponent(deviceId)}`);
      state.selectedDeviceIds.delete(deviceId);
    } catch (err) {
      failures.push(`${deviceId}: ${err.message}`);
    }
  }
  if (failures.length) {
    if (devicesListStatus) {
      devicesListStatus.textContent = t("deletedWithFailures", { count: failures.length });
    }
  } else if (devicesListStatus) {
    devicesListStatus.textContent = t("deleted");
  }
  await loadDevices();
}

function toggleDevicesSelection(deviceId, isChecked, rowEl) {
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

function updateDevicesSelectAllState(items) {
  if (!selectAllDevices) {
    return;
  }
  const visible = items || [];
  if (!visible.length) {
    selectAllDevices.checked = false;
    selectAllDevices.indeterminate = false;
    return;
  }
  let selectedCount = 0;
  visible.forEach((d) => {
    if (state.selectedDeviceIds.has(d.device_id)) {
      selectedCount += 1;
    }
  });
  if (selectedCount === 0) {
    selectAllDevices.checked = false;
    selectAllDevices.indeterminate = false;
  } else if (selectedCount === visible.length) {
    selectAllDevices.checked = true;
    selectAllDevices.indeterminate = false;
  } else {
    selectAllDevices.checked = false;
    selectAllDevices.indeterminate = true;
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

const deviceEditModal = createModal();
const deviceEditIdInput = deviceEditModal.card.querySelector("#modalDeviceId");
const deviceEditMainSelect = deviceEditModal.card.querySelector("#modalMainSelect");
const deviceEditSubSelect = deviceEditModal.card.querySelector("#modalSubSelect");
const deviceEditStatus = deviceEditModal.card.querySelector(".modal-status");
const deviceEditSave = deviceEditModal.card.querySelector(".modal-save");
const deviceEditCancel = deviceEditModal.card.querySelector(".modal-cancel");
let deviceEditOriginalId = null;

const bulkEditModal = createBulkEditModal();
const bulkEditMainSelect = bulkEditModal.card.querySelector("#bulkMainSelect");
const bulkEditSubSelect = bulkEditModal.card.querySelector("#bulkSubSelect");
const bulkEditStatus = bulkEditModal.card.querySelector(".bulk-status");
const bulkEditCount = bulkEditModal.card.querySelector(".bulk-count");
const bulkEditSave = bulkEditModal.card.querySelector(".bulk-save");
const bulkEditCancel = bulkEditModal.card.querySelector(".bulk-cancel");
let bulkEditDeviceIds = [];
refreshDeviceModalTexts();
refreshBulkEditModalTexts();

deviceEditCancel.addEventListener("click", () => closeModal(deviceEditModal));
deviceEditSave.addEventListener("click", async () => {
  if (!deviceEditOriginalId) {
    return;
  }
  deviceEditStatus.textContent = t("saving");
  try {
    const payload = {
      device_id: deviceEditIdInput.value.trim().toUpperCase(),
      main_category_id: Number(deviceEditMainSelect.value),
      sub_category_id: Number(deviceEditSubSelect.value),
    };
    await apiPut(`/api/v1/devices/${encodeURIComponent(deviceEditOriginalId)}`, payload);
    deviceEditStatus.textContent = t("saved");
    closeModal(deviceEditModal);
    await loadDevices();
  } catch (err) {
    deviceEditStatus.textContent = t("failed", { message: err.message });
  }
});

deviceEditMainSelect.addEventListener("change", () => {
  renderSubCategorySelect(deviceEditSubSelect, Number(deviceEditMainSelect.value), false);
});

bulkEditCancel.addEventListener("click", () => closeModal(bulkEditModal));
bulkEditSave.addEventListener("click", async () => {
  if (!bulkEditDeviceIds.length) {
    return;
  }
  bulkEditStatus.textContent = t("saving");
  const payloadBase = {
    main_category_id: Number(bulkEditMainSelect.value),
    sub_category_id: Number(bulkEditSubSelect.value),
  };
  const failures = [];
  for (const deviceId of bulkEditDeviceIds) {
    try {
      await apiPut(`/api/v1/devices/${encodeURIComponent(deviceId)}`, {
        device_id: deviceId,
        ...payloadBase,
      });
    } catch (err) {
      failures.push(`${deviceId}: ${err.message}`);
    }
  }
  if (failures.length) {
    bulkEditStatus.textContent = t("savedWithFailures", { count: failures.length });
  } else {
    bulkEditStatus.textContent = t("saved");
    closeModal(bulkEditModal);
  }
  await loadDevices();
});

bulkEditMainSelect.addEventListener("change", () => {
  renderSubCategorySelect(bulkEditSubSelect, Number(bulkEditMainSelect.value), false);
});

function openDeviceEditModal(device) {
  deviceEditOriginalId = device.device_id;
  deviceEditStatus.textContent = "";
  deviceEditIdInput.value = device.device_id;
  renderMainCategorySelect(deviceEditMainSelect, false);
  deviceEditMainSelect.value = String(device.main_category_id || "");
  renderSubCategorySelect(deviceEditSubSelect, Number(device.main_category_id), false);
  deviceEditSubSelect.value = String(device.sub_category_id || "");
  openModal(deviceEditModal);
}

function openBulkEditModal(deviceIds) {
  bulkEditDeviceIds = [...deviceIds];
  bulkEditStatus.textContent = "";
  bulkEditCount.textContent = t("selectedDevicesCount", { count: bulkEditDeviceIds.length });
  renderMainCategorySelect(bulkEditMainSelect, false);
  renderSubCategorySelect(bulkEditSubSelect, Number(bulkEditMainSelect.value), false);
  openModal(bulkEditModal);
}

function refreshDeviceModalTexts() {
  deviceEditModal.card.querySelector("h3").textContent = t("editDevice");
  const labels = deviceEditModal.card.querySelectorAll("label");
  labels[0].childNodes[0].textContent = `${t("deviceId")} `;
  labels[1].childNodes[0].textContent = `${t("faculty")} `;
  labels[2].childNodes[0].textContent = `${t("yearIntake")} `;
  deviceEditModal.card.querySelector(".modal-cancel").textContent = t("cancel");
  deviceEditModal.card.querySelector(".modal-save").textContent = t("save");
}

function refreshBulkEditModalTexts() {
  bulkEditModal.card.querySelector("h3").textContent = t("editSelectedDevices");
  const labels = bulkEditModal.card.querySelectorAll("label");
  labels[0].childNodes[0].textContent = `${t("faculty")} `;
  labels[1].childNodes[0].textContent = `${t("yearIntake")} `;
  bulkEditModal.card.querySelector(".bulk-cancel").textContent = t("cancel");
  bulkEditModal.card.querySelector(".bulk-save").textContent = t("save");
  if (bulkEditDeviceIds.length) {
    bulkEditCount.textContent = t("selectedDevicesCount", {
      count: bulkEditDeviceIds.length,
    });
  }
}

function createModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = `
    <div class="modal-card">
      <h3>${escapeHtml(t("editDevice"))}</h3>
      <div class="form-grid">
        <label>${escapeHtml(t("deviceId"))} <input id="modalDeviceId" type="text" required /></label>
        <label>${escapeHtml(t("faculty"))} <select id="modalMainSelect" required></select></label>
        <label>${escapeHtml(t("yearIntake"))} <select id="modalSubSelect" required></select></label>
      </div>
      <p class="status modal-status"></p>
      <div class="modal-actions">
        <button type="button" class="modal-cancel">${escapeHtml(t("cancel"))}</button>
        <button type="button" class="modal-save">${escapeHtml(t("save"))}</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (event) => {
    if (event.target === overlay) {
      closeModal({ overlay });
    }
  });
  return { overlay, card: overlay.querySelector(".modal-card") };
}

function createBulkEditModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = `
    <div class="modal-card">
      <h3>${escapeHtml(t("editSelectedDevices"))}</h3>
      <p class="status bulk-count"></p>
      <div class="form-grid">
        <label>${escapeHtml(t("faculty"))} <select id="bulkMainSelect" required></select></label>
        <label>${escapeHtml(t("yearIntake"))} <select id="bulkSubSelect" required></select></label>
      </div>
      <p class="status bulk-status"></p>
      <div class="modal-actions">
        <button type="button" class="bulk-cancel">${escapeHtml(t("cancel"))}</button>
        <button type="button" class="bulk-save">${escapeHtml(t("save"))}</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (event) => {
    if (event.target === overlay) {
      closeModal({ overlay });
    }
  });
  return { overlay, card: overlay.querySelector(".modal-card") };
}

function openModal(modal) {
  modal.overlay.classList.remove("hidden");
}

function closeModal(modal) {
  modal.overlay.classList.add("hidden");
}
