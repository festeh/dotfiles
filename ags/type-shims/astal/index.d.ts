import type GLib from "gi://GLib"

export interface Subscribable<T = unknown> {
    get(): T
    subscribe(callback: (value: T) => void): () => void
}

export interface Binding<T = unknown> extends Subscribable<T> {
    as<R>(transform: (value: T) => R): Binding<R>
}

export interface Connectable {
    connect(signal: string, callback: (...args: any[]) => unknown): number
    disconnect(id: number): void
    [key: string]: any
}

export interface Variable<T> extends Subscribable<T> {
    <R>(transform: (value: T) => R): Binding<R>
    (): Binding<T>
    set(value: T): void
    poll(interval: number, callback: (prev: T) => T | Promise<T>): Variable<T>
    poll(interval: number, exec: string | string[], transform?: (stdout: string, prev: T) => T): Variable<T>
    watch(exec: string | string[], transform?: (stdout: string, prev: T) => T): Variable<T>
    observe(
        objs: Array<[obj: Connectable, signal: string]>,
        callback: (...args: any[]) => T,
    ): Variable<T>
    observe(
        obj: Connectable,
        signal: string,
        callback: (...args: any[]) => T,
    ): Variable<T>
    drop(): void
    onDropped(callback: () => void): Variable<T>
    onError(callback: (err: string) => void): Variable<T>
}

type Values<Deps extends readonly Subscribable<any>[]> = {
    [K in keyof Deps]: Deps[K] extends Subscribable<infer T> ? T : never
}

export const Variable: {
    <T>(init: T): Variable<T>
    new<T>(init: T): Variable<T>
    derive<const Deps extends readonly Subscribable<any>[], V = Values<Deps>>(
        deps: Deps,
        fn?: (...args: Values<Deps>) => V,
    ): Variable<V>
}

export function bind<T>(subscribable: Subscribable<T>): Binding<T>
export function bind<T extends object, K extends keyof T>(object: T, property: K): Binding<T[K]>
export function bind(object: Connectable | object, property: string): Binding<any>

export function timeout(timeout: number, callback?: () => void): { cancel?: () => void } | unknown
export function interval(interval: number, callback?: () => void): { cancel?: () => void } | unknown
export function idle(callback?: () => void): { cancel?: () => void } | unknown

export function exec(cmd: string | string[]): string
export function execAsync(cmd: string | string[]): Promise<string>

export { default as GLib } from "gi://GLib"
export type { GLib }
