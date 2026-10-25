export const STORAGE_KEY = 'glassdeck.web.v1';
export const emptyState = () => ({ version: 1, tasks: [], notes: '', timer: { duration: 1500, remaining: 1500, endAt: null, completed: 0 } });
export function validateState(value) {
  if (!value || value.version !== 1 || !Array.isArray(value.tasks) || value.tasks.length > 1000 || typeof value.notes !== 'string' || value.notes.length > 100000) throw new Error('Invalid backup');
  const ids = new Set();
  for (const task of value.tasks) {
    if (!task || typeof task.id !== 'string' || !task.id || ids.has(task.id) || typeof task.text !== 'string' || !task.text.trim() || task.text.length > 200 || typeof task.done !== 'boolean') throw new Error('Invalid task');
    ids.add(task.id);
  }
  const t = value.timer;
  if (!t || !Number.isInteger(t.duration) || t.duration < 60 || t.duration > 10800 || !Number.isFinite(t.remaining) || t.remaining < 0 || t.remaining > t.duration || !(t.endAt === null || (Number.isFinite(t.endAt) && t.endAt >= 0)) || !Number.isInteger(t.completed) || t.completed < 0) throw new Error('Invalid timer');
  return { version: 1, tasks: value.tasks.map(({id,text,done}) => ({id,text,done})), notes: value.notes, timer: {...t} };
}
export function remaining(timer, now = Date.now()) {
  return timer.endAt === null ? timer.remaining : Math.max(0, Math.min(timer.duration, Math.ceil((timer.endAt - now) / 1000)));
}
export function settleTimer(timer, now = Date.now()) {
  const left = remaining(timer, now);
  return timer.endAt !== null && left === 0 ? {...timer, endAt: null, remaining: 0, completed: timer.completed + 1} : timer;
}
export function convert(value, from, to, category) {
  if (!Number.isFinite(value)) throw new Error('Enter a number');
  if (category === 'temperature') {
    if (!['C','F','K'].includes(from) || !['C','F','K'].includes(to)) throw new Error('Invalid unit');
    const c = from === 'C' ? value : from === 'F' ? (value - 32) * 5 / 9 : value - 273.15;
    if (c < -273.15000001) throw new Error('Below absolute zero');
    return to === 'C' ? c : to === 'F' ? c * 9 / 5 + 32 : c + 273.15;
  }
  const factors = {m:1, km:1000, cm:.01, mm:.001, in:.0254, ft:.3048, mi:1609.344};
  if (!(from in factors) || !(to in factors)) throw new Error('Invalid unit');
  return value * factors[from] / factors[to];
}
