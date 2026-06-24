const state = {
  selectedSlot: null,
  slots: 4,
  canDelete: true,
  characters: {}
};

const emptyBoxHtml = `
  <h3 class="character-fullname"><i class="fas fa-plus"></i></h3>
  <div class="character-info"><p class="character-info-new">Neuen Charakter erstellen</p></div>
`;

function postNui(eventName, payload = {}) {
  fetch(`https://${GetParentResourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(payload)
  }).catch(() => {});
}

function normalizeCharacters(characters, slots) {
  const out = {};
  if (!characters) return out;

  if (Array.isArray(characters)) {
    for (let i = 0; i < characters.length; i += 1) {
      const entry = characters[i];
      if (entry && entry.id) out[entry.id] = entry;
      else if (entry) out[i + 1] = entry;
    }
    return out;
  }

  for (let i = 1; i <= slots; i += 1) {
    if (characters[i]) out[i] = characters[i];
    else if (characters[String(i)]) out[i] = characters[String(i)];
    else if (characters["slot" + i]) out[i] = characters["slot" + i];
  }

  for (const key in characters) {
    const entry = characters[key];
    if (entry && entry.id) out[entry.id] = entry;
  }

  return out;
}

function resetBox(slot) {
  const box = $(`.character-box[data-charid="${slot}"]`);
  box.removeClass("active-char disabled-char");
  box.attr("data-ischar", "false");
  box.html(emptyBoxHtml);
}

function fillBox(slot, character) {
  const box = $(`.character-box[data-charid="${slot}"]`);
  const fullName = `${character.firstname || ""} ${character.lastname || ""}`.trim() || "Unbekannt";
  const disabled = character.disabled === true || character.disabled === 1;

  box.attr("data-ischar", "true");
  box.toggleClass("disabled-char", disabled);
  box.html(`
    <h3 class="character-fullname">${fullName}</h3>
    <div class="character-info">
      <p><strong>Geburtsdatum:</strong> ${character.dateofbirth || "-"}</p>
      <p><strong>Geschlecht:</strong> ${character.sex || "-"}</p>
      <p><strong>Job:</strong> ${character.job || "-"} ${character.job_grade || ""}</p>
      <p><strong>Bar:</strong> $${character.money || 0}</p>
      <p><strong>Bank:</strong> $${character.bank || 0}</p>
      ${disabled ? '<p class="char-disabled-label">Charakter deaktiviert</p>' : ""}
    </div>
  `);
}

function renderAll() {
  for (let i = 1; i <= state.slots; i += 1) {
    if (state.characters[i]) fillBox(i, state.characters[i]);
    else resetBox(i);
  }

  $(`.character-box`).each(function () {
    const slot = Number($(this).data("charid"));
    $(this).toggle(slot <= state.slots);
  });

  updateButtons();
}

function setActive(slot) {
  state.selectedSlot = slot;
  $(".character-box").removeClass("active-char");
  $(`.character-box[data-charid="${slot}"]`).addClass("active-char");
  postNui("selectCharacter", { slot });
  updateButtons();
}

function updateButtons() {
  const slot = state.selectedSlot;
  const character = slot ? state.characters[slot] : null;
  const hasChar = !!character;
  const isDisabled = hasChar && (character.disabled === true || character.disabled === 1);

  if (!slot) {
    $(".character-buttons").hide();
    $("#delete").hide();
    $("#play-char").text("SPIELEN").prop("disabled", true);
    return;
  }

  $(".character-buttons").show();
  $("#play-char").prop("disabled", isDisabled);

  if (hasChar) {
    $("#play-char").text("SPIELEN");
    $("#delete").toggle(state.canDelete);
  } else {
    $("#play-char").text("ERSTELLEN");
    $("#delete").hide();
  }
}

function showUi() {
  $(".main-container").stop(true, true).fadeIn(100);
}

function hideUi() {
  $(".main-container").hide();
  hideDeleteConfirm();
  state.selectedSlot = null;
  $(".character-box").removeClass("active-char");
  $(".character-buttons").hide();
}

function showDeleteConfirm() {
  $("#delete-confirm").addClass("show");
}

function hideDeleteConfirm() {
  $("#delete-confirm").removeClass("show");
}

window.addEventListener("message", (event) => {
  const data = event.data || {};

  if (data.action === "setupui") {
    hideDeleteConfirm();
    state.slots = Number(data.slots) || 4;
    state.canDelete = data.canDelete !== false;
    state.characters = normalizeCharacters(data.characters, state.slots);
    state.selectedSlot = null;
    renderAll();

    const firstWithChar = Object.keys(state.characters).map(Number).sort((a, b) => a - b)[0];
    if (firstWithChar) setActive(firstWithChar);
    else setActive(1);

    if (data.show === true) {
      showUi();
    }
  } else if (data.action === "closeui") {
    hideUi();
  }
});

$(document).on("click", ".character-box", function () {
  const slot = Number($(this).data("charid"));
  if (!slot || slot > state.slots) return;
  setActive(slot);
});

$("#play-char").on("click", () => {
  const slot = state.selectedSlot;
  if (!slot) return;

  const character = state.characters[slot];
  if (character && (character.disabled === true || character.disabled === 1)) return;

  if (character) postNui("playCharacter", { slot });
  else postNui("createCharacter", { slot });
});

$("#delete").on("click", () => {
  const slot = state.selectedSlot;
  if (!slot || !state.characters[slot] || !state.canDelete) return;
  postNui("selectCharacter", { slot });
  showDeleteConfirm();
});

$("#cancel-delete").on("click", () => {
  hideDeleteConfirm();
});

$("#deletechar").on("click", () => {
  if (!state.selectedSlot || !state.characters[state.selectedSlot]) return;
  hideDeleteConfirm();
  postNui("deleteCharacter", { slot: state.selectedSlot });
});

hideUi();
