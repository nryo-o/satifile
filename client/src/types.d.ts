declare module "*.elm" {
  export const Elm: {
    Main: {
      init: (options: Options) => {
        ports: Ports
      }
    }
  }
}


type Options = {
  // Since they will be decoded in elm, we dont need to define types here
  flags: Record<string, unknown>
}


type Ports = {
  portReceive: { send: (msg: { tag: string, [keys: string]: unknown }) => void }
  portSend: { subscribe: (callback: (message: Action) => void) => void }
}

type A<T extends string, Data> = Data & {
  tag: T
}

type Action = A<"copy", { text: string }>

