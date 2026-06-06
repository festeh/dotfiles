/// <reference path="./@girs/gjs.d.ts" />
/// <reference path="./@girs/dom.d.ts" />
/// <reference path="./@girs/astal-4.0.d.ts" />
/// <reference path="./@girs/astalapps-0.1.d.ts" />
/// <reference path="./@girs/astalbattery-0.1.d.ts" />
/// <reference path="./@girs/astalhyprland-0.1.d.ts" />
/// <reference path="./@girs/astalnotifd-0.1.d.ts" />
/// <reference path="./@girs/astaltray-0.1.d.ts" />
/// <reference path="./@girs/astalwp-0.1.d.ts" />

declare const SRC: string

declare module "inline:*" {
    const content: string
    export default content
}

declare module "*.sass" {
    const content: string
    export default content
}

declare module "*.scss" {
    const content: string
    export default content
}

declare module "*.css" {
    const content: string
    export default content
}
