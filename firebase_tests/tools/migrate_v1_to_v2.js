import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Refusing to migrate outside the Firestore emulator.');
}

initializeApp({ projectId: 'demo-message-board-vault' });
const database = getFirestore();
const snapshot = await database.collection('messages').get();
const legacyDocuments = snapshot.docs.filter((document) => {
  const version = document.data().schemaVersion ?? 1;
  return version < 2;
});

if (legacyDocuments.length === 0) {
  console.log('No v1 documents required migration.');
  process.exit(0);
}

const batch = database.batch();
for (const document of legacyDocuments) {
  const before = document.data();
  const text = before.text ?? before.content;
  const authorUid = before.authorUid ?? before.ownerUid;
  const authorName = before.authorName ?? before.ownerName;
  const createdAt = before.createdAt ?? before.timestamp;
  if (!text || !authorUid || !authorName || !createdAt) {
    throw new Error(`Document ${document.id} is corrupt; migration stopped before commit.`);
  }
  batch.update(document.ref, {
    text,
    authorUid,
    authorName,
    createdAt,
    editedAt: null,
    schemaVersion: 2,
    clientRequestId: `migrated-${document.id}`,
    content: FieldValue.delete(),
    ownerUid: FieldValue.delete(),
    ownerName: FieldValue.delete(),
    timestamp: FieldValue.delete(),
  });
}

await batch.commit();

for (const original of legacyDocuments) {
  const after = (await original.ref.get()).data();
  if (after.schemaVersion !== 2 || after.text !== original.data().content) {
    throw new Error(`Post-migration verification failed for ${original.id}.`);
  }
}

console.log(`Migrated and verified ${legacyDocuments.length} v1 documents without data loss.`);
