# Alert Service Usage

## Data Model
```
/users/{uid}/alerts/active/items/{alertId}
/users/{uid}/alerts/past/items/{alertId}
```
Each alert document:
```
{
  type: "geofencing" | "panic",
  triggeredAt: Timestamp,
  resolvedAt: Timestamp | null,
  location: { latitude: number, longitude: number },
  extra: { ... }
}
```

## API
```js
const { createAlert, resolveAlert, listenActiveAlerts, fetchAllActiveAlerts } = require('./services/alertService');
```

### createAlert
```js
await createAlert(uid, 'panic', { latitude: 12.34, longitude: 56.78 }, { notifiedPolice: false });
```

### resolveAlert
```js
await resolveAlert(uid, alertId);
```

### listenActiveAlerts
```js
const unsubscribe = listenActiveAlerts(uid, (alerts) => {
  console.log(alerts);
});
// later
unsubscribe();
```

### fetchAllActiveAlerts
```js
const all = await fetchAllActiveAlerts();
```

## Security Rule Suggestions (Firestore)
```
match /users/{uid}/alerts/{state}/items/{alertId} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```
For an admin/police dashboard, use custom claims or a separate backend using the Admin SDK (preferred) to aggregate `fetchAllActiveAlerts`.
