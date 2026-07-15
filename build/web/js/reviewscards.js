import { reviews } from '../data/reviewsdata.js';

const reviewsTrack = document.getElementById('reviews-track');

reviews.forEach(review => {
    const reviewCard = document.createElement('div');
    reviewCard.classList.add('review-card');
    reviewCard.innerHTML = `
  <div class="review-card-top">
    <img src="${review.profilePicture}" alt="${review.name}" class="review-profile-picture">
    
    <div class="review-card-info">
    <div class="review-card-info-left">
      <h3 class="review-name">${review.name}</h3>
      <p class="review-role">${review.role}</p>
      </div>
      <div class="review-rating">
        ${'★'.repeat(review.rating)}${'☆'.repeat(5 - review.rating)}
      </div>
    </div>
  </div>

  <p class="review-text">"${review.review}"</p>
`;
    reviewsTrack.appendChild(reviewCard);
});

// 🔥 duplicate content for seamless loop
reviewsTrack.innerHTML += reviewsTrack.innerHTML;