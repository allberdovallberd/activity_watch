const mainCategoryForm = document.getElementById("mainCategoryForm");
const mainCategoryNameInput = document.getElementById("mainCategoryNameInput");
const mainStatus = document.getElementById("mainStatus");
const mainBody = document.getElementById("mainBody");

const subCategoryForm = document.getElementById("subCategoryForm");
const subMainSelect = document.getElementById("subMainSelect");
const subCategoryNameInput = document.getElementById("subCategoryNameInput");
const subStatus = document.getElementById("subStatus");
const subBody = document.getElementById("subBody");

initSharedLayout("categories");
initAuth(async () => {
  await loadCategories();
  renderAll();
});
document.addEventListener("usage-language-changed", () => {
  refreshMainEditModalTexts();
  refreshSubEditModalTexts();
  renderAll();
});

mainCategoryForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  mainStatus.textContent = t("saving");
  try {
    const payload = { name: mainCategoryNameInput.value.trim() };
    await apiPost("/api/v1/main-categories", payload);
    mainCategoryNameInput.value = "";
    await loadCategories();
    renderAll();
    mainStatus.textContent = t("saved");
  } catch (err) {
    mainStatus.textContent = t("failed", { message: err.message });
  }
});

subCategoryForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  subStatus.textContent = t("saving");
  try {
    const payload = {
      name: subCategoryNameInput.value.trim(),
      main_category_id: Number(subMainSelect.value),
    };
    await apiPost("/api/v1/sub-categories", payload);
    subCategoryNameInput.value = "";
    await loadCategories();
    renderAll();
    subStatus.textContent = t("saved");
  } catch (err) {
    subStatus.textContent = t("failed", { message: err.message });
  }
});

function renderAll() {
  renderMainCategorySelect(subMainSelect, false);
  renderMainTable();
  renderSubTable();
}

function renderMainTable() {
  if (!appState.mainCategories.length) {
    mainBody.innerHTML = `<tr><td colspan="2">${escapeHtml(t("noMainCategories"))}</td></tr>`;
    return;
  }
  mainBody.innerHTML = "";
  appState.mainCategories.forEach((cat) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(cat.name)}</td>
      <td class="actions-col">
        <button type="button" class="edit-btn" data-id="${cat.id}">${escapeHtml(t("edit"))}</button>
        <button type="button" class="danger delete-btn" data-id="${cat.id}">${escapeHtml(t("delete"))}</button>
      </td>
    `;
    mainBody.appendChild(tr);
  });
  mainBody.querySelectorAll(".edit-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = Number(btn.dataset.id);
      const cat = appState.mainCategories.find((c) => c.id === id);
      if (!cat) {
        return;
      }
      openMainEditModal(cat);
    });
  });
  mainBody.querySelectorAll(".delete-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const id = Number(btn.dataset.id);
      const name = appState.mainCategories.find((c) => c.id === id)?.name || "";
      const ok = await confirmDialog(
        t("deleteMainCategoryConfirm", { name }),
        t("delete"),
        t("cancel"),
      );
      if (!ok) {
        return;
      }
      try {
        await apiDelete(`/api/v1/main-categories/${id}`);
        await loadCategories();
        renderAll();
      } catch (err) {
        mainStatus.textContent = t("deleteFailed", { message: err.message });
      }
    });
  });
}

function renderSubTable() {
  if (!appState.subCategories.length) {
    subBody.innerHTML = `<tr><td colspan="3">${escapeHtml(t("noSubCategories"))}</td></tr>`;
    return;
  }
  subBody.innerHTML = "";
  appState.subCategories.forEach((sub) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(sub.main_category_name || "")}</td>
      <td>${escapeHtml(sub.name)}</td>
      <td class="actions-col">
        <button type="button" class="edit-btn" data-id="${sub.id}">${escapeHtml(t("edit"))}</button>
        <button type="button" class="danger delete-btn" data-id="${sub.id}">${escapeHtml(t("delete"))}</button>
      </td>
    `;
    subBody.appendChild(tr);
  });
  subBody.querySelectorAll(".edit-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = Number(btn.dataset.id);
      const sub = appState.subCategories.find((s) => s.id === id);
      if (!sub) {
        return;
      }
      openSubEditModal(sub);
    });
  });
  subBody.querySelectorAll(".delete-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const id = Number(btn.dataset.id);
      const sub = appState.subCategories.find((s) => s.id === id);
      const label = sub ? `${sub.main_category_name || ""} / ${sub.name}` : "";
      const ok = await confirmDialog(
        t("deleteSubCategoryConfirm", { label }),
        t("delete"),
        t("cancel"),
      );
      if (!ok) {
        return;
      }
      try {
        await apiDelete(`/api/v1/sub-categories/${id}`);
        await loadCategories();
        renderAll();
      } catch (err) {
        subStatus.textContent = t("deleteFailed", { message: err.message });
      }
    });
  });
}

const mainEditModal = createMainEditModal();
const subEditModal = createSubEditModal();
refreshMainEditModalTexts();
refreshSubEditModalTexts();

function createMainEditModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = `
    <div class="modal-card">
      <h3>${escapeHtml(t("editMainCategory"))}</h3>
      <label>${escapeHtml(t("name"))} <input id="modalMainName" type="text" required /></label>
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
      overlay.classList.add("hidden");
    }
  });
  return {
    overlay,
    input: overlay.querySelector("#modalMainName"),
    status: overlay.querySelector(".modal-status"),
    save: overlay.querySelector(".modal-save"),
    cancel: overlay.querySelector(".modal-cancel"),
    id: null,
  };
}

function createSubEditModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = `
    <div class="modal-card">
      <h3>${escapeHtml(t("editSubCategory"))}</h3>
      <label>${escapeHtml(t("main"))} <select id="modalSubMainSelect" required></select></label>
      <label>${escapeHtml(t("name"))} <input id="modalSubName" type="text" required /></label>
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
      overlay.classList.add("hidden");
    }
  });
  return {
    overlay,
    select: overlay.querySelector("#modalSubMainSelect"),
    input: overlay.querySelector("#modalSubName"),
    status: overlay.querySelector(".modal-status"),
    save: overlay.querySelector(".modal-save"),
    cancel: overlay.querySelector(".modal-cancel"),
    id: null,
  };
}

mainEditModal.cancel.addEventListener("click", () => {
  mainEditModal.overlay.classList.add("hidden");
});
mainEditModal.save.addEventListener("click", async () => {
  if (!mainEditModal.id) {
    return;
  }
  mainEditModal.status.textContent = t("saving");
  try {
    await apiPut(`/api/v1/main-categories/${mainEditModal.id}`, {
      name: mainEditModal.input.value.trim(),
    });
    mainEditModal.status.textContent = t("saved");
    mainEditModal.overlay.classList.add("hidden");
    await loadCategories();
    renderAll();
  } catch (err) {
    mainEditModal.status.textContent = t("failed", { message: err.message });
  }
});

subEditModal.cancel.addEventListener("click", () => {
  subEditModal.overlay.classList.add("hidden");
});
subEditModal.save.addEventListener("click", async () => {
  if (!subEditModal.id) {
    return;
  }
  subEditModal.status.textContent = t("saving");
  try {
    await apiPut(`/api/v1/sub-categories/${subEditModal.id}`, {
      name: subEditModal.input.value.trim(),
      main_category_id: Number(subEditModal.select.value),
    });
    subEditModal.status.textContent = t("saved");
    subEditModal.overlay.classList.add("hidden");
    await loadCategories();
    renderAll();
  } catch (err) {
    subEditModal.status.textContent = t("failed", { message: err.message });
  }
});

function openMainEditModal(cat) {
  mainEditModal.id = cat.id;
  mainEditModal.input.value = cat.name;
  mainEditModal.status.textContent = "";
  mainEditModal.overlay.classList.remove("hidden");
}

function openSubEditModal(sub) {
  subEditModal.id = sub.id;
  renderMainCategorySelect(subEditModal.select, false);
  subEditModal.select.value = String(sub.main_category_id || "");
  subEditModal.input.value = sub.name;
  subEditModal.status.textContent = "";
  subEditModal.overlay.classList.remove("hidden");
}

function refreshMainEditModalTexts() {
  mainEditModal.overlay.querySelector("h3").textContent = t("editMainCategory");
  mainEditModal.overlay.querySelector("label").childNodes[0].textContent = `${t("name")} `;
  mainEditModal.cancel.textContent = t("cancel");
  mainEditModal.save.textContent = t("save");
}

function refreshSubEditModalTexts() {
  subEditModal.overlay.querySelector("h3").textContent = t("editSubCategory");
  const labels = subEditModal.overlay.querySelectorAll("label");
  labels[0].childNodes[0].textContent = `${t("main")} `;
  labels[1].childNodes[0].textContent = `${t("name")} `;
  subEditModal.cancel.textContent = t("cancel");
  subEditModal.save.textContent = t("save");
}
