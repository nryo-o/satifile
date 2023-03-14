import formidable from "formidable";
import http, { IncomingMessage } from "http";

export const uploadFiles_ =
  (opts: formidable.Options) => (req: IncomingMessage) => (res: http.ServerResponse) => () =>
    new Promise((ressolve, rej) => {
      const form = formidable(opts);

      form.parse(req, (err, fields, files: formidable.Files) => {
        const file = zipIfNeeded(Object.values(files));

        if (!file.originalFilename) {
          rej("Unnamed file");
        }

        if (!file.mimetype) {
          rej("Missing mimetype");
        }

        if (err) {
          rej(err);
        }

        ressolve({
          size: file.size,
          filepath: file.filepath,
          originalFilename: file.originalFilename,
          newFilename: file.newFilename,
          mimetype: file.mimetype,
          hash: file.hash,
        });
      });
    });

export const fetchAsync_ = async (id: number) => {
  return Promise.resolve(id);
};

function zipIfNeeded(
  files: (formidable.File | formidable.File[])[]
): formidable.File {
  // TODO: Zip multiple files
  const head = files[0];
  if (Array.isArray(head)) {
    return head[0];
  } else {
    return head;
  }
}
