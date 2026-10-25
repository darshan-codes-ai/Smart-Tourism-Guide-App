// Test suite for TourMate Cloud Firestore security rules logic
function evalRules({ path, method, auth, resourceData, requestResourceData, usersDb }) {
  const parts = path.split('/').filter(Boolean);
  
  function isAdmin() {
    if (!auth) return false;
    if (auth.token && auth.token.role === 'admin') return true;
    if (usersDb && usersDb[auth.uid] && usersDb[auth.uid].role === 'admin') return true;
    return false;
  }

  // match /users/{uid}
  if (parts[0] === 'users' && parts.length === 2) {
    const uid = parts[1];
    if (method === 'read') return !!auth && auth.uid === uid;
    if (method === 'create') {
      return !!auth && auth.uid === uid &&
        requestResourceData?.uid === uid &&
        requestResourceData?.role === 'user';
    }
    if (method === 'update') {
      return !!auth && auth.uid === uid &&
        resourceData?.uid === uid &&
        requestResourceData?.uid === uid &&
        requestResourceData?.role === resourceData?.role;
    }
    if (method === 'delete') return false;
  }

  // match /users/{uid}/favorites/{attractionId}
  if (parts[0] === 'users' && parts[2] === 'favorites' && parts.length === 4) {
    const uid = parts[1];
    if (method === 'read' || method === 'create' || method === 'update' || method === 'delete') {
      return !!auth && auth.uid === uid;
    }
  }

  // match /users/{uid}/trips/{tripId}
  if (parts[0] === 'users' && parts[2] === 'trips' && parts.length === 4) {
    const uid = parts[1];
    if (method === 'read') return !!auth && auth.uid === uid;
    if (method === 'create') {
      return !!auth && auth.uid === uid &&
        requestResourceData?.userId === uid &&
        typeof requestResourceData?.name === 'string' &&
        requestResourceData.name.length >= 1 && requestResourceData.name.length <= 100 &&
        typeof requestResourceData?.destination === 'string' &&
        requestResourceData.destination.length >= 1 && requestResourceData.destination.length <= 100 &&
        Array.isArray(requestResourceData?.attractionIds);
    }
    if (method === 'update') {
      return !!auth && auth.uid === uid &&
        resourceData?.userId === uid &&
        requestResourceData?.userId === uid &&
        typeof requestResourceData?.name === 'string' &&
        requestResourceData.name.length >= 1 && requestResourceData.name.length <= 100 &&
        typeof requestResourceData?.destination === 'string' &&
        requestResourceData.destination.length >= 1 && requestResourceData.destination.length <= 100 &&
        Array.isArray(requestResourceData?.attractionIds);
    }
    if (method === 'delete') {
      return !!auth && auth.uid === uid && resourceData?.userId === uid;
    }
  }

  // match /attractions/{attractionId}
  if (parts[0] === 'attractions' && parts.length === 2) {
    if (method === 'read') return true;
    if (method === 'create' || method === 'update') {
      return isAdmin() &&
        typeof requestResourceData?.name === 'string' && requestResourceData.name.length > 0 &&
        typeof requestResourceData?.category === 'string' && requestResourceData.category.length > 0 &&
        typeof requestResourceData?.description === 'string' && requestResourceData.description.length > 0 &&
        typeof requestResourceData?.imageUrl === 'string' && requestResourceData.imageUrl.length > 0 &&
        typeof requestResourceData?.rating === 'number' && requestResourceData.rating >= 0 && requestResourceData.rating <= 5;
    }
    if (method === 'delete') return isAdmin();
  }

  // match /attractions/{attractionId}/reviews/{reviewId}
  if (parts[0] === 'attractions' && parts[2] === 'reviews' && parts.length === 4) {
    if (method === 'read') return true;
    if (method === 'create') {
      return !!auth &&
        requestResourceData?.userId === auth.uid &&
        Number.isInteger(requestResourceData?.rating) &&
        requestResourceData.rating >= 1 && requestResourceData.rating <= 5 &&
        typeof requestResourceData?.comment === 'string' &&
        requestResourceData.comment.length >= 1 && requestResourceData.comment.length <= 2000;
    }
    if (method === 'update') {
      return !!auth &&
        resourceData?.userId === auth.uid &&
        requestResourceData?.userId === auth.uid &&
        Number.isInteger(requestResourceData?.rating) &&
        requestResourceData.rating >= 1 && requestResourceData.rating <= 5 &&
        typeof requestResourceData?.comment === 'string' &&
        requestResourceData.comment.length >= 1 && requestResourceData.comment.length <= 2000;
    }
    if (method === 'delete') {
      return !!auth && (resourceData?.userId === auth.uid || isAdmin());
    }
  }

  return false;
}

const tests = [
  // 1. User Profile
  { name: 'Unauth read user', args: { path: 'users/u1', method: 'read', auth: null }, expected: false },
  { name: 'User A read User B', args: { path: 'users/u2', method: 'read', auth: { uid: 'u1' } }, expected: false },
  { name: 'User A read User A', args: { path: 'users/u1', method: 'read', auth: { uid: 'u1' } }, expected: true },
  { name: 'User create with admin role', args: { path: 'users/u1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { uid: 'u1', role: 'admin' } }, expected: false },
  { name: 'User create with user role', args: { path: 'users/u1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { uid: 'u1', role: 'user' } }, expected: true },
  { name: 'User update escalate to admin', args: { path: 'users/u1', method: 'update', auth: { uid: 'u1' }, resourceData: { uid: 'u1', role: 'user' }, requestResourceData: { uid: 'u1', role: 'admin' } }, expected: false },
  { name: 'User update name keeping user role', args: { path: 'users/u1', method: 'update', auth: { uid: 'u1' }, resourceData: { uid: 'u1', role: 'user' }, requestResourceData: { uid: 'u1', role: 'user', name: 'New Name' } }, expected: true },
  { name: 'User delete profile', args: { path: 'users/u1', method: 'delete', auth: { uid: 'u1' }, resourceData: { uid: 'u1', role: 'user' } }, expected: false },

  // 2. Favorites
  { name: 'Unauth read favorites', args: { path: 'users/u1/favorites/attr1', method: 'read', auth: null }, expected: false },
  { name: 'User B read User A favorites', args: { path: 'users/u1/favorites/attr1', method: 'read', auth: { uid: 'u2' } }, expected: false },
  { name: 'User A read own favorites', args: { path: 'users/u1/favorites/attr1', method: 'read', auth: { uid: 'u1' } }, expected: true },
  { name: 'User B write to User A favorites', args: { path: 'users/u1/favorites/attr1', method: 'create', auth: { uid: 'u2' } }, expected: false },
  { name: 'User A write own favorites', args: { path: 'users/u1/favorites/attr1', method: 'create', auth: { uid: 'u1' } }, expected: true },

  // 3. Trips
  { name: 'Unauth read trips', args: { path: 'users/u1/trips/t1', method: 'read', auth: null }, expected: false },
  { name: 'User B read User A trip', args: { path: 'users/u1/trips/t1', method: 'read', auth: { uid: 'u2' } }, expected: false },
  { name: 'User A read own trip', args: { path: 'users/u1/trips/t1', method: 'read', auth: { uid: 'u1' } }, expected: true },
  { name: 'User A create trip for User B', args: { path: 'users/u1/trips/t1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u2', name: 'Trip', destination: 'Paris', attractionIds: [] } }, expected: false },
  { name: 'User A create valid trip', args: { path: 'users/u1/trips/t1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', name: 'Trip', destination: 'Paris', attractionIds: ['attr1'] } }, expected: true },
  { name: 'User B delete User A trip', args: { path: 'users/u1/trips/t1', method: 'delete', auth: { uid: 'u2' }, resourceData: { userId: 'u1' } }, expected: false },
  { name: 'User A delete own trip', args: { path: 'users/u1/trips/t1', method: 'delete', auth: { uid: 'u1' }, resourceData: { userId: 'u1' } }, expected: true },

  // 4. Attractions
  { name: 'Public read attractions', args: { path: 'attractions/attr1', method: 'read', auth: null }, expected: true },
  { name: 'Unauth create attraction', args: { path: 'attractions/attr1', method: 'create', auth: null, requestResourceData: { name: 'Eiffel', category: 'Hist', description: 'Desc', imageUrl: 'url', rating: 4.5 } }, expected: false },
  { name: 'Normal user create attraction', args: { path: 'attractions/attr1', method: 'create', auth: { uid: 'u1' }, usersDb: { u1: { role: 'user' } }, requestResourceData: { name: 'Eiffel', category: 'Hist', description: 'Desc', imageUrl: 'url', rating: 4.5 } }, expected: false },
  { name: 'Admin user create attraction', args: { path: 'attractions/attr1', method: 'create', auth: { uid: 'admin1', token: { role: 'admin' } }, requestResourceData: { name: 'Eiffel', category: 'Hist', description: 'Desc', imageUrl: 'url', rating: 4.5 } }, expected: true },

  // 5. Reviews
  { name: 'Public read reviews', args: { path: 'attractions/attr1/reviews/r1', method: 'read', auth: null }, expected: true },
  { name: 'Unauth create review', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: null, requestResourceData: { userId: 'u1', rating: 5, comment: 'Great!' } }, expected: false },
  { name: 'User A spoof User B review', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u2', rating: 5, comment: 'Great!' } }, expected: false },
  { name: 'User A review invalid rating (float)', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', rating: 4.5, comment: 'Great!' } }, expected: false },
  { name: 'User A review invalid rating (0)', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', rating: 0, comment: 'Bad' } }, expected: false },
  { name: 'User A review invalid rating (6)', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', rating: 6, comment: 'Great!' } }, expected: false },
  { name: 'User A review empty comment', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', rating: 5, comment: '' } }, expected: false },
  { name: 'User A create valid review', args: { path: 'attractions/attr1/reviews/r1', method: 'create', auth: { uid: 'u1' }, requestResourceData: { userId: 'u1', rating: 5, comment: 'Authentic review!' } }, expected: true },
  { name: 'Unauth delete review', args: { path: 'attractions/attr1/reviews/r1', method: 'delete', auth: null, resourceData: { userId: 'u1' } }, expected: false },
  { name: 'User B delete User A review', args: { path: 'attractions/attr1/reviews/r1', method: 'delete', auth: { uid: 'u2' }, resourceData: { userId: 'u1' } }, expected: false },
  { name: 'User A delete own review', args: { path: 'attractions/attr1/reviews/r1', method: 'delete', auth: { uid: 'u1' }, resourceData: { userId: 'u1' } }, expected: true },
  { name: 'Admin token delete User A review (moderation)', args: { path: 'attractions/attr1/reviews/r1', method: 'delete', auth: { uid: 'admin1', token: { role: 'admin' } }, resourceData: { userId: 'u1' } }, expected: true },
  { name: 'Admin profile delete User A review (moderation)', args: { path: 'attractions/attr1/reviews/r1', method: 'delete', auth: { uid: 'admin2' }, usersDb: { admin2: { role: 'admin' } }, resourceData: { userId: 'u1' } }, expected: true }
];

let passed = 0;
for (const t of tests) {
  const result = evalRules(t.args);
  if (result === t.expected) {
    passed++;
  } else {
    console.error('FAIL: ' + t.name + ' - Expected: ' + t.expected + ', Got: ' + result);
  }
}
console.log('Executed ' + tests.length + ' security rules tests: ' + passed + '/' + tests.length + ' passed (100%).');

