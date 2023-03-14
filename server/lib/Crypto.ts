import crypto from "crypto";

export const sha256sum = (buffer: crypto.BinaryLike) =>
  crypto.createHash("sha256").update(buffer).digest("hex");

export const randomBytesString_ = (size: number) => () =>
  new Promise((res, rej) => {
    crypto.randomBytes(size, (err, buf) => {
      if (err) {
        rej(err);
      }

      const hex = buf.toString("hex");
      res(hex);
    });
  });
