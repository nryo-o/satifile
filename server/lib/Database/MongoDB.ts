import mongodb, { BSON, Filter, MongoClient } from "mongodb";
import { customAlphabet, nanoid } from "nanoid";


const lowercaseDict = "abcdefghijklmnopqrstuvwxyz"
const uppercaseDict = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const numbersDict = "0123456789"
const alphanumericDict = numbersDict + lowercaseDict + uppercaseDict


export const safeid = customAlphabet(alphanumericDict, 21)

export const connect_ = (config: string) => (): Promise<MongoClient> => {
  const client = new MongoClient(config);
  return client.connect();
};

export const close_ = (client: MongoClient) => async (): Promise<void> => {
  return await client.close();
};

type Config = {
  db: string;
  collection: string;
};

export const findOne_ =
  (client: MongoClient) =>
    ({ db, collection }: Config) =>
      (query: Filter<BSON.Document>) =>
        async () => {
          const res = await client.db(db).collection(collection).findOne(query);
          return res;
        };

export const findMany_ =
  (client: MongoClient) =>
    ({ db, collection }: Config) =>
      (query: Filter<BSON.Document>) =>
        async () => {
          const res = await client.db(db).collection(collection).find(query).toArray();
          return res;
        };

export const insertOne_ =
  (client: MongoClient) =>
    ({ db, collection }: Config) =>
      (document: mongodb.OptionalId<mongodb.BSON.Document>) =>
        async () => {
          const id = document.id ? document.id : safeid()
          await client.db(db).collection(collection).insertOne({ id, ...document });
          return id;
        };

export const updateOne_ =
  (client: MongoClient) =>
    ({ db, collection }: Config) =>
      (query: mongodb.Filter<mongodb.BSON.Document>) =>
        (update: mongodb.UpdateFilter<mongodb.BSON.Document> | Partial<mongodb.BSON.Document>) =>
          async () => {
            const doc = await client.db(db).collection(collection).findOneAndUpdate(query, update, { returnDocument: "after" });
            return doc.value
          };
