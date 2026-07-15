
function openSupportModal() {
  document.getElementById("supportModal").style.display = "flex";
}

function closeSupportModal() {
  document.getElementById("supportModal").style.display = "none";
}

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