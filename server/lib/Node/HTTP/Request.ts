import http, { IncomingMessage } from "http";

export const onCloseImpl = (req: IncomingMessage) => (handler: () => void) => () => {
  req.on("close", handler);
};
