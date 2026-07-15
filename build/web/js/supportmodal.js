
function openSupportModal() {
  document.getElementById("supportModal").style.display = "flex";
}

function closeSupportModal() {
  document.getElementById("supportModal").style.display = "none";
}

document.addEventListener("DOMContentLoaded", function () {
  const supportModal = document.getElementById("supportModal");
  const supportCard = supportModal?.querySelector(".support-card");

  if (!supportModal || !supportCard) {
    return;
  }

  supportModal.addEventListener("click", function (event) {
    if (!supportCard.contains(event.target)) {
      closeSupportModal();
    }
  });
});

// ACTIONS (edit these links)
function openFacebook() {
  window.open("https://facebook.com/ppctodaofficial");
}

function sendSMS() {
  window.location.href = "sms:+639686410532";
}

function callUs() {
  window.location.href = "tel:+639686410532";
}

function requestCancel() {
  alert("Request cancellation triggered");
}
