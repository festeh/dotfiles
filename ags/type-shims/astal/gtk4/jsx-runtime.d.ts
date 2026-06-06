export function jsx(ctor: unknown, props: Record<string, any>): any
export function jsxs(ctor: unknown, props: Record<string, any>): any
export function Fragment(props: { child?: any; children?: any[] }): any

declare global {
    namespace JSX {
        type Element = any
        interface IntrinsicElements {
            [element: string]: any
        }
    }
}
