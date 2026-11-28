const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { test, before, after, beforeEach } = require('node:test');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, Timestamp } = require('firebase/firestore');

let env;
const identity = () => ({
  displayName: 'Persona de prueba', createdAt: Timestamp.fromMillis(1000),
  currentMode: 3, consentGiven: false, consentDate: null,
});
const userDoc = (uid = 'adult') => doc(env.authenticatedContext(uid).firestore(), 'users/adult');
async function seed(extra = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/adult'), { ...identity(), ...extra });
  });
}
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-auroracare-rules',
    firestore: { rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
beforeEach(async () => { await env.clearFirestore(); });
after(async () => { await env?.cleanup(); });

test('legacy registration remains valid without sharing fields', async () => {
  await assertSucceeds(setDoc(userDoc(), { ...identity(), currentMode: 0 }));
});
test('personal mode accepts the exact new transaction payload', async () => {
  await seed();
  await assertSucceeds(updateDoc(userDoc(), {
    currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 1,
  }));
});
test('mode cycle preserves generation on return to mode 3 and increments on mode 2', async () => {
  await seed();
  await assertSucceeds(updateDoc(userDoc(), { currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 1 }));
  await assertSucceeds(updateDoc(userDoc(), { currentMode: 3, caregiverSharingEnabled: false }));
  await assertSucceeds(updateDoc(userDoc(), { currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 2 }));
});
test('retry on mode 2 does not require another increment', async () => {
  await seed({ currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 1 });
  await assertSucceeds(updateDoc(userDoc(), { currentMode: 2, caregiverSharingEnabled: false }));
});
test('switch to personal requires cancelling sharing and advancing generation', async () => {
  await seed();
  await assertFails(updateDoc(userDoc(), { currentMode: 2 }));
});
test('sharing cannot be enabled by the owner client', async () => {
  await seed();
  await assertFails(updateDoc(userDoc(), { caregiverSharingEnabled: true }));
});
test('generation cannot be skipped, reset, or replaced with a fractional value', async () => {
  await seed({ caregiverAccessEpoch: 4, caregiverSharingEnabled: false });
  for (const epoch of [0, 6, 4.5, '5', -1]) {
    await assertFails(updateDoc(userDoc(), { currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: epoch }));
  }
});
test('another account cannot change the adult mode', async () => {
  await seed();
  await assertFails(updateDoc(userDoc('another'), { currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 1 }));
});
test('identity document still rejects cognitive UUID and metrics', async () => {
  await seed();
  await assertFails(updateDoc(userDoc(), { uuid: 'cognitive-profile' }));
  await assertFails(updateDoc(userDoc(), { precisionPct: 80 }));
});
test('existing consent and medical disclaimer are preserved', async () => {
  const accepted = Timestamp.fromMillis(2000);
  await seed({ consentGiven: true, consentDate: accepted, disclaimerAcceptedAt: accepted });
  await assertSucceeds(updateDoc(userDoc(), { currentMode: 2, caregiverSharingEnabled: false, caregiverAccessEpoch: 1 }));
  await assertFails(updateDoc(userDoc(), { disclaimerAcceptedAt: Timestamp.fromMillis(3000) }));
});
test('incomplete caregiver link and invite payloads are rejected', async () => {
  const db = env.authenticatedContext('adult').firestore();
  for (const collection of ['caregiver_links', 'caregiver_invites']) {
    await assertFails(setDoc(doc(db, collection, 'test'), { status: 'active' }));
  }
});

test('caregiver registration stores identity only and cannot opt into metrics', async () => {
  await assertSucceeds(setDoc(userDoc(), { ...identity(), role: 'caregiver', currentMode: 0 }));
  await assertFails(updateDoc(userDoc(), { currentMode: 3 }));
  await assertFails(updateDoc(userDoc(), { consentGiven: true }));
});
test('account role cannot be changed or removed after caregiver registration', async () => {
  await seed({ role: 'caregiver', currentMode: 0 });
  await assertFails(updateDoc(userDoc(), { role: 'elder' }));
  await assertFails(setDoc(userDoc(), { ...identity(), currentMode: 0 }));
});
test('legacy elder accounts cannot switch themselves into a caregiver role', async () => {
  await seed();
  await assertFails(updateDoc(userDoc(), { role: 'caregiver', currentMode: 0 }));
});
