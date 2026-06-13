export function elapsed(fun) {
  const start = Number(process.hrtime.bigint());
  const result = fun();
  const stop = Number(process.hrtime.bigint());
  return [result, stop - start];
}

export function exit(n) {
  process.exit(n);
}
