const adminOverlay = document.getElementById("adminOverlay");
const adminForm = document.getElementById("adminForm");
const adminUsernameInput = document.getElementById("adminUsernameInput");
const adminPasswordInput = document.getElementById("adminPasswordInput");
const adminStatus = document.getElementById("adminStatus");
const adminContent = document.getElementById("adminContent");
const backendUrlInput = document.getElementById("backendUrlInput");
const saveBackendUrlBtn = document.getElementById("saveBackendUrlBtn");
const backendUrlStatus = document.getElementById("backendUrlStatus");
const createUserForm = document.getElementById("createUserForm");
const newUsernameInput = document.getElementById("newUsernameInput");
const newPasswordInput = document.getElementById("newPasswordInput");
const createUserStatus = document.getElementById("createUserStatus");
const usersBody = document.getElementById("usersBody");
const usersStatus = document.getElementById("usersStatus");
const logoutBtn = document.getElementById("logoutBtn");

const adminState = {
  token: "",
  username: "",
};

const userEditModal = createUserEditModal();
let editingUsername = "";

if (logoutBtn) {
  logoutBtn.dataset.bound = "1";
  logoutBtn.addEventListener("click", async () => {
    const ok = await confirmDialog(t("logOutConfirm"), t("confirm"), t("cancel"));
    if (!ok) {
      return;
    }
    adminState.token = "";
    adminState.username = "";
    openAdminOverlay();
  });
}

initSharedLayout("admin");
backendUrlInput.value = appState.backendUrl;
applySharedTranslations();
refreshUserEditModalTexts();
openAdminOverlay();

document.addEventListener("usage-language-changed", () => {
  refreshUserEditModalTexts();
  if (adminState.token) {
    loadUsers();
  }
});

adminForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  adminStatus.textContent = t("adminCheckingCredentials");
  try {
    const payload = await fetchJson("/api/v1/admin/login", {
      method: "POST",
      body: JSON.stringify({
        username: adminUsernameInput.value.trim(),
        password: adminPasswordInput.value.trim(),
      }),
    });
    adminState.token = payload.token;
    adminState.username = adminUsernameInput.value.trim();
    adminPasswordInput.value = "";
    adminStatus.textContent = "";
    adminOverlay.classList.add("hidden");
    setAdminContentVisible(true);
    await loadUsers();
  } catch (err) {
    adminStatus.textContent = t("adminLoginFailed", { message: err.message });
  }
});

saveBackendUrlBtn.addEventListener("click", () => {
  const next = normalizeBackendUrl(backendUrlInput.value) || normalizeBackendUrl(BACKEND_BASE_URL);
  appState.backendUrl = next;
  localStorage.setItem(BACKEND_URL_KEY, next);
  backendUrlInput.value = next;
  backendUrlStatus.textContent = t("backendUrlSaved");
});

createUserForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  createUserStatus.textContent = t("creatingUser");
  try {
    await adminApi("/api/v1/users", {
      method: "POST",
      body: JSON.stringify({
        username: newUsernameInput.value.trim(),
        password: newPasswordInput.value.trim(),
      }),
    });
    newUsernameInput.value = "";
    newPasswordInput.value = "";
    createUserStatus.textContent = t("userCreated");
    await loadUsers();
  } catch (err) {
    createUserStatus.textContent = t("createFailed", { message: err.message });
  }
});

function openAdminOverlay(statusMessage = "") {
  adminStatus.textContent = statusMessage;
  adminPasswordInput.value = "";
  setAdminContentVisible(false);
  adminOverlay.classList.remove("hidden");
}

function setAdminContentVisible(isVisible) {
  if (adminContent) {
    adminContent.classList.toggle("hidden", !isVisible);
  }
}

async function loadUsers() {
  usersStatus.textContent = t("loadingUsers");
  try {
    const payload = await adminApi("/api/v1/users");
    renderUsers(payload.users || []);
    usersStatus.textContent = "";
  } catch (err) {
    usersBody.innerHTML = "";
    usersStatus.textContent = t("loadFailed", { message: err.message });
  }
}

function renderUsers(users) {
  const visibleUsers = (users || []).filter((user) => {
    const username = String(user?.username || "").trim().toLowerCase();
    if (!username) {
      return false;
    }
    if (username === "admin") {
      return false;
    }
    if (adminState.username && username === adminState.username.trim().toLowerCase()) {
      return false;
    }
    return true;
  });
  if (!visibleUsers.length) {
    usersBody.innerHTML = `<tr><td colspan="3">${escapeHtml(t("noUsersFound"))}</td></tr>`;
    return;
  }
  usersBody.innerHTML = "";
  visibleUsers.forEach((user) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(user.username || "")}</td>
      <td>${escapeHtml(formatTurkmenTime(user.updated_at))}</td>
      <td class="actions-col">
        <button type="button" class="edit-user-btn">${escapeHtml(t("edit"))}</button>
        <button type="button" class="danger delete-user-btn">${escapeHtml(t("delete"))}</button>
      </td>
    `;
    tr.querySelector(".edit-user-btn").addEventListener("click", () => openUserEditModal(user));
    tr.querySelector(".delete-user-btn").addEventListener("click", () => deleteUser(user));
    usersBody.appendChild(tr);
  });
}

function createUserEditModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = `
    <div class="modal-card">
      <h3></h3>
      <div class="form-grid">
        <label><span class="user-edit-username-label"></span> <input id="editUserUsernameInput" type="text" required /></label>
        <label><span class="user-edit-password-label"></span> <input id="editUserPasswordInput" type="password" required /></label>
      </div>
      <p class="status user-edit-status"></p>
      <div class="modal-actions">
        <button type="button" class="modal-cancel"></button>
        <button type="button" class="modal-save"></button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (event) => {
    if (event.target === overlay) {
      closeUserEditModal();
    }
  });
  overlay.querySelector(".modal-cancel").addEventListener("click", closeUserEditModal);
  overlay.querySelector(".modal-save").addEventListener("click", submitUserEditModal);
  return {
    overlay,
    title: overlay.querySelector("h3"),
    usernameLabel: overlay.querySelector(".user-edit-username-label"),
    passwordLabel: overlay.querySelector(".user-edit-password-label"),
    usernameInput: overlay.querySelector("#editUserUsernameInput"),
    passwordInput: overlay.querySelector("#editUserPasswordInput"),
    status: overlay.querySelector(".user-edit-status"),
    cancel: overlay.querySelector(".modal-cancel"),
    save: overlay.querySelector(".modal-save"),
  };
}

function refreshUserEditModalTexts() {
  userEditModal.title.textContent = t("edit");
  userEditModal.usernameLabel.textContent = t("username");
  userEditModal.passwordLabel.textContent = t("newPassword");
  userEditModal.usernameInput.placeholder = t("username");
  userEditModal.passwordInput.placeholder = t("newPassword");
  userEditModal.cancel.textContent = t("cancel");
  userEditModal.save.textContent = t("save");
}

function openUserEditModal(user) {
  editingUsername = user.username || "";
  userEditModal.usernameInput.value = editingUsername;
  userEditModal.passwordInput.value = "";
  userEditModal.status.textContent = "";
  refreshUserEditModalTexts();
  userEditModal.overlay.classList.remove("hidden");
}

function closeUserEditModal() {
  userEditModal.overlay.classList.add("hidden");
  userEditModal.status.textContent = "";
  userEditModal.passwordInput.value = "";
}

async function submitUserEditModal() {
  const nextUsername = userEditModal.usernameInput.value.trim();
  const nextPassword = userEditModal.passwordInput.value.trim();
  if (!nextUsername || !nextPassword) {
    userEditModal.status.textContent = t("missingUsernamePassword");
    return;
  }
  const confirmed = await confirmDialog(
    t("saveUserChangesConfirm", { username: nextUsername }),
    t("confirm"),
    t("cancel"),
  );
  if (!confirmed) {
    return;
  }
  userEditModal.status.textContent = t("updatingUser", { username: editingUsername });
  try {
    await adminApi(`/api/v1/users/${encodeURIComponent(editingUsername)}`, {
      method: "PUT",
      body: JSON.stringify({
        username: nextUsername,
        password: nextPassword,
      }),
    });
    usersStatus.textContent = t("passwordUpdatedForUser", { username: nextUsername });
    closeUserEditModal();
    await loadUsers();
  } catch (err) {
    userEditModal.status.textContent = t("passwordUpdateFailed", { message: err.message });
  }
}

async function deleteUser(user) {
  const username = String(user?.username || "").trim();
  if (!username) {
    return;
  }
  const confirmed = await confirmDialog(
    t("deleteUserConfirm", { username }),
    t("confirm"),
    t("cancel"),
  );
  if (!confirmed) {
    return;
  }
  usersStatus.textContent = t("deleting");
  try {
    await adminApi(`/api/v1/users/${encodeURIComponent(username)}`, {
      method: "DELETE",
    });
    usersStatus.textContent = t("userDeleted", { username });
    await loadUsers();
  } catch (err) {
    usersStatus.textContent = t("userDeleteFailed", { message: err.message });
  }
}

async function adminApi(path, options = {}) {
  if (!adminState.token) {
    throw new Error(t("adminAuthenticationRequired"));
  }
  return fetchJson(path, {
    ...options,
    headers: {
      ...(options.headers || {}),
      Authorization: `Bearer ${adminState.token}`,
    },
  });
}

async function fetchJson(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  const response = await fetch(`${appState.backendUrl}${path}`, {
    ...options,
    headers,
  });
  const payload = await safeJson(response);
  if (!response.ok) {
    throw new Error(translateBackendError(payload.error || `HTTP ${response.status}`));
  }
  return payload;
}
