document.getElementById("check-health-btn").addEventListener("click", async () => {
  const result = document.getElementById("health-result");
  result.textContent = "Checking...";

  const response = await fetch("/health");
  const data = await response.json();

  result.textContent = `Status: ${data.status} | DB: ${data.database} | Version: ${data.version}`;
});

document.getElementById("save-note-btn").addEventListener("click", async () => {
  const userId = document.getElementById("new-note-user-id").value;
  const title = document.getElementById("new-note-title").value;
  const body = document.getElementById("new-note-body").value;
  const result = document.getElementById("save-note-result");

  const response = await fetch("/notes", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user_id: Number(userId), title, body }),
  });

  if (response.status === 201) {
    result.textContent = "Note saved!";
    document.getElementById("new-note-title").value = "";
    document.getElementById("new-note-body").value = "";
  } else {
    result.textContent = "Something went wrong.";
  }
});

async function loadNotes() {
  const userId = document.getElementById("notes-user-id").value;
  const list = document.getElementById("notes-list");

  list.innerHTML = "Loading...";

  const response = await fetch(`/notes?user_id=${userId}`);
  const notes = await response.json();

  if (notes.length === 0) {
    list.innerHTML = "<li>No notes found.</li>";
    return;
  }

  list.innerHTML = notes.map(note => `
    <li data-id="${note.id}">
      <strong>${note.title}</strong>
      <p>${note.body || "(no body)"}</p>
      <button class="delete-note-btn" data-id="${note.id}">Delete</button>
    </li>
  `).join("");
}

document.getElementById("load-notes-btn").addEventListener("click", loadNotes);

document.getElementById("notes-list").addEventListener("click", async (event) => {
  if (!event.target.classList.contains("delete-note-btn")) return;

  const noteId = event.target.dataset.id;

  await fetch(`/notes/${noteId}`, { method: "DELETE" });

  loadNotes();
});
