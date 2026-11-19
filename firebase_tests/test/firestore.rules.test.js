import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-message-board-vault';
const rules = readFileSync(resolve(import.meta.dirname, '../../firestore.rules'), 'utf8');
let testEnvironment;

const message = (uid, requestId = 'request-1') => ({
  text: 'A rule-tested message',
  authorUid: uid,
  authorName: uid === 'alice' ? 'Alice Tester' : 'Bob Tester',
  createdAt: serverTimestamp(),
  editedAt: null,
  schemaVersion: 2,
  clientRequestId: requestId,
});

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: { host: '127.0.0.1', port: 8080, rules },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

async function seedMessage(id = 'owned-message', owner = 'alice') {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'messages', id), {
      ...message(owner),
      createdAt: new Date('2026-11-19T12:00:00Z'),
    });
  });
}

test('signed-out reads are denied by Firestore', async () => {
  await seedMessage();
  const guest = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(guest, 'messages', 'owned-message')));
});

test('another uid cannot update or delete an owned message', async () => {
  await seedMessage();
  const bob = testEnvironment.authenticatedContext('bob').firestore();
  const reference = doc(bob, 'messages', 'owned-message');

  await assertFails(updateDoc(reference, { text: 'Hijacked', editedAt: serverTimestamp() }));
  await assertFails(deleteDoc(reference));
});

test('forging authorUid on create is denied', async () => {
  const bob = testEnvironment.authenticatedContext('bob').firestore();
  await assertFails(setDoc(doc(bob, 'messages', 'forged'), message('alice', 'forged-request')));
});

test('the correct author can complete the full CRUD cycle', async () => {
  const alice = testEnvironment.authenticatedContext('alice').firestore();
  const reference = doc(alice, 'messages', 'alice_request-1');

  await assertSucceeds(setDoc(reference, message('alice')));
  const created = await assertSucceeds(getDoc(reference));
  assert.equal(created.data().text, 'A rule-tested message');

  await assertSucceeds(
    updateDoc(reference, { text: 'Edited by the owner', editedAt: serverTimestamp() }),
  );
  const updated = await assertSucceeds(getDoc(reference));
  assert.equal(updated.data().text, 'Edited by the owner');
  await assertSucceeds(deleteDoc(reference));
});

test('a private user record is readable only by its uid', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'alice'), {
      uid: 'alice',
      firstName: 'Alice',
      lastName: 'Tester',
      role: 'graduateStudent',
      registrationDateTime: new Date('2026-11-19T12:00:00Z'),
    });
  });
  const alice = testEnvironment.authenticatedContext('alice').firestore();
  const bob = testEnvironment.authenticatedContext('bob').firestore();

  await assertSucceeds(getDoc(doc(alice, 'users', 'alice')));
  await assertFails(getDoc(doc(bob, 'users', 'alice')));
});
