import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Refusing to seed outside the Firestore emulator.');
}

initializeApp({ projectId: 'demo-message-board-vault' });
const database = getFirestore();
const batch = database.batch();

const fixtures = [
  {
    id: 'legacy-welcome',
    content: 'Welcome from the v1 schema',
    ownerUid: 'migration-user',
    ownerName: 'Migration Tester',
    timestamp: Timestamp.fromDate(new Date('2026-11-17T14:00:00Z')),
  },
  {
    id: 'legacy-offline',
    content: 'This message survived an offline queue',
    ownerUid: 'migration-user',
    ownerName: 'Migration Tester',
    timestamp: Timestamp.fromDate(new Date('2026-11-18T15:30:00Z')),
  },
];

for (const fixture of fixtures) {
  const { id, ...data } = fixture;
  batch.set(database.collection('messages').doc(id), data);
}

await batch.commit();
console.log(`Seeded ${fixtures.length} realistic v1 message documents in the emulator.`);
