'use strict';

/* ==========================================================================
   Vanguard Jobs - Job Portal + on-screen tracker
   Opened in a normal browser it runs a preview with sample data: #home, #team, #run, #tracker.
   ========================================================================== */

const IS_GAME = typeof GetParentResourceName === 'function';
const RESOURCE = IS_GAME ? GetParentResourceName() : 'vanguard-jobs';
const AVATAR_COLOURS = ['#10b981', '#3b82f6', '#f59e0b', '#ec4899'];
const CLOSE_ANIMATION_MS = 220;

const ui = { data: null, mode: null, ring: 0 };

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function el(tag, props = {}, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
        if (value === null || value === undefined || value === false) continue;
        if (key === 'class') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key === 'style') node.setAttribute('style', value);
        else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
        else node.setAttribute(key, value === true ? '' : value);
    }
    node.append(...children.flat().filter((child) => child !== null && child !== undefined && child !== false));
    return node;
}

function setChildren(node, ...children) {
    node.replaceChildren(...children.flat().filter((child) => child !== null && child !== undefined && child !== false));
}

const SVG_NS = 'http://www.w3.org/2000/svg';
const ICONS = {
    box: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="M3 8l9 5 9-5M12 13v8"/>',
    recycle: '<path d="M7 19H4.8a1.8 1.8 0 0 1-1.5-2.7L5.5 12.5"/><path d="M11 19h8.2a1.8 1.8 0 0 0 1.5-2.7l-1.4-2.4"/><path d="m14 16-3 3 3 3"/><path d="M8.3 6.2 9.5 4.1a1.8 1.8 0 0 1 3.1 0l3.9 6.8"/><path d="m13.4 10.9 3.1.8.8-3.1"/><path d="m4.6 12.3 1-3.1 3 .8"/>',
    bag: '<path d="M6 8h12l-1 13H7z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
    crown: '<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z" fill="currentColor"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    play: '<path d="M7 5l12 7-12 7z" fill="currentColor"/>',
    flag: '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>',
    leave: '<path d="M15 4h4v16h-4M10 17l5-5-5-5M15 12H3"/>',
    check: '<path d="M5 12l5 5 9-11"/>',
};

function icon(name) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.innerHTML = ICONS[name] || ICONS.box; // fixed markup from ICONS only
    return svg;
}

const money = (value) => `$${Math.floor(Number(value) || 0).toLocaleString('en-US')}`;

/** Same maths as shared/rules.lua Rules.payout, for estimates. */
function payout(job, stopsDone, totalStops, size, bonus) {
    if (stopsDone <= 0) return 0;
    let base = job.payPerStop * stopsDone;
    if (totalStops > 0 && stopsDone >= totalStops) base += job.routeBonus;
    const pct = (bonus && bonus[size]) || (Array.isArray(bonus) && bonus[size - 1]) || 100;
    return Math.floor((base * pct) / 100);
}

function bonusFor(data, size) {
    const bonus = data.bonus || {};
    return (Array.isArray(bonus) ? bonus[size - 1] : bonus[size]) || 100;
}

async function post(endpoint, data = {}) {
    if (!IS_GAME) return Preview.respond(endpoint, data);
    try {
        const response = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await response.json();
    } catch {
        return { ok: false, message: 'The game did not answer' };
    }
}

function toast(message, ok = true) {
    if (!message) return;
    const node = el('div', { class: `toast${ok ? '' : ' is-error'}`, role: 'status', text: message });
    document.getElementById('toasts').append(node);
    setTimeout(() => node.classList.add('is-leaving'), 3200);
    setTimeout(() => node.remove(), 3600);
}

/** Runs a server action from a button; the server pushes the new state itself. */
async function act(button, action, data) {
    if (button) button.classList.add('is-busy');
    const result = await post('request', { action, data });
    if (button) button.classList.remove('is-busy');
    toast(result.message, result.ok);
    return result;
}

// ---------------------------------------------------------------------------
// Team panel
// ---------------------------------------------------------------------------

function memberSlot(member, index, data) {
    const isMe = member.id === data.me;
    const canKick = data.isLeader && !isMe && !(data.team && data.team.busy);
    return el('div', { class: 'slot', style: `--i:${index}` },
        el('span', { class: 'avatar', style: `--c:${AVATAR_COLOURS[index % AVATAR_COLOURS.length]}` },
            member.name.charAt(0).toUpperCase(),
            member.leader ? (() => { const c = icon('crown'); c.classList.add('crown'); return c; })() : null),
        el('span', { class: 'slot-text' },
            el('strong', { text: member.name }),
            el('small', { text: `${member.leader ? 'Team leader' : 'Member'}${isMe ? ' · you' : ''} · ID ${member.id}` })),
        canKick ? el('button', {
            class: 'kick', type: 'button', title: 'Remove from team',
            onclick: (event) => act(event.currentTarget, 'kick', { target: member.id }),
        }, icon('close')) : null);
}

function renderTeam(data) {
    if (!data.team) {
        const teams = data.openTeams || [];
        return el('div', { class: 'view', style: 'display:flex;flex-direction:column;gap:16px;height:100%' },
            el('div', {},
                el('div', { class: 'kicker', text: 'Your team' }),
                el('div', { class: 'title', text: 'Not in a team' }),
                el('p', { class: 'subtitle', text: `Work alone or with up to ${data.maxSize - 1} friends. Bigger teams earn more - for everyone.` })),
            el('button', {
                class: 'btn is-primary is-wide', type: 'button',
                onclick: (event) => act(event.currentTarget, 'createTeam'),
            }, icon('plus'), 'Create team'),
            el('div', { class: 'divider' }, el('span', { class: 'kicker', text: 'Open teams' })),
            teams.length
                ? el('div', { class: 'open-teams' }, teams.map((team, index) => el('div', { class: 'open-team', style: `--i:${index}` },
                    el('span', { class: 'avatar', style: `--c:${AVATAR_COLOURS[index % AVATAR_COLOURS.length]}` }, team.leader.charAt(0).toUpperCase()),
                    el('span', { class: 'slot-text' },
                        el('strong', { text: `${team.leader}'s team` }),
                        el('span', { class: 'dots' }, Array.from({ length: data.maxSize }, (_, i) => el('i', { class: i < team.size ? 'on' : '' })))),
                    el('button', {
                        class: 'btn is-small', type: 'button',
                        onclick: (event) => act(event.currentTarget, 'joinTeam', { teamId: team.id }),
                    }, 'Join'))))
                : el('div', { class: 'empty', text: 'No open teams right now. Create one and your friends can join it from their Job Portal.' }));
    }

    const members = data.team.members;
    const size = members.length;
    const bonus = bonusFor(data, size);
    const slots = members.map((member, index) => memberSlot(member, index, data));
    for (let i = size; i < data.maxSize; i++) {
        slots.push(el('div', { class: 'slot is-empty', style: `--i:${i}` },
            el('span', { class: 'avatar' }),
            el('span', { class: 'slot-text' }, el('strong', { text: 'Open slot' }), el('small', { text: 'Friends join from their Job Portal' }))));
    }

    return el('div', { class: 'view', style: 'display:flex;flex-direction:column;gap:16px;height:100%' },
        el('div', { class: 'row-between' },
            el('div', {},
                el('div', { class: 'kicker', text: data.team.busy ? 'On the job' : 'Your team' }),
                el('div', { class: 'title', text: `Team #${data.team.id}` })),
            el('span', { class: bonus > 100 ? 'chip' : 'chip is-muted', text: bonus > 100 ? `+${bonus - 100}% BONUS` : 'SOLO' })),
        el('div', { class: 'slots' }, slots),
        el('div', { class: 'team-foot' },
            el('button', {
                class: 'btn is-ghost is-wide', type: 'button',
                onclick: (event) => act(event.currentTarget, 'leaveTeam'),
            }, icon('leave'), 'Leave team')));
}

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

function stat(label, value) {
    return el('div', { class: 'stat' }, el('small', { text: label }), el('strong', { text: value }));
}

function renderJobs(data) {
    const size = data.team ? data.team.members.length : 1;
    const canStart = data.team && data.isLeader;
    return el('div', { class: 'view' },
        el('div', { class: 'kicker', text: data.center || 'Job Center' }),
        el('div', { class: 'title', text: 'Choose a job' }),
        el('p', { class: 'subtitle', text: `The leader starts the job at the Job Center. The work vehicle appears in the parking lot and the leader gets the keys. Vehicle deposit ${money(data.deposit)}, refunded when you bring it back.` }),
        el('div', { class: 'jobs' }, data.jobs.map((job, index) => {
            const each = payout(job, job.stops, job.stops, size, data.bonus);
            const label = !data.team ? 'Create a team to start' : (canStart ? 'Start job' : 'Waiting for the leader');
            return el('article', { class: 'job', style: `--i:${index}` },
                el('div', { class: 'job-head' },
                    el('span', { class: 'job-icon' }, icon(job.icon)),
                    el('div', {}, el('div', { class: 'job-name', text: job.label }), el('div', { class: 'kicker', text: `${job.stops} stops · ${job.units}` }))),
                el('p', { class: 'job-desc', text: job.description }),
                el('div', { class: 'stats' },
                    stat('PER STOP', money(job.payPerStop)),
                    stat('ROUTE BONUS', `+${money(job.routeBonus)}`),
                    stat('TEAM', `${size} / ${data.maxSize}`)),
                el('div', { class: 'earn' },
                    el('small', { text: size > 1 ? `Each of your ${size} members earns` : 'You earn for the full route' }),
                    el('strong', { text: money(each) })),
                el('button', {
                    class: `btn ${canStart ? 'is-primary' : ''} is-wide`, type: 'button', disabled: !canStart,
                    onclick: (event) => act(event.currentTarget, 'startJob', { job: job.id }),
                }, canStart ? icon('play') : null, label));
        })),
        el('p', { class: 'note', text: `Team bonus for every member: 2 players +${bonusFor(data, 2) - 100}%, 3 players +${bonusFor(data, 3) - 100}%, 4 players +${bonusFor(data, 4) - 100}%. Paid once into the bank when the job ends.` }));
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

function stepText(run) {
    if (run.phase === 'return') {
        return { title: 'Route done!', text: 'Drive the vehicle back to the Job Center parking lot. The leader presses Finish there and everyone gets paid.' };
    }
    const vehicle = run.jobId === 'recycling' ? 'truck' : 'van';
    const left = run.unitsTotal - run.unitsDone;
    const what = `${left} ${left === 1 ? run.unit : run.units}`;
    if (run.pickup === 'vehicle') {
        return { title: `Stop ${run.stopIndex}: ${what} left to deliver`, text: `Follow the GPS route. At the stop, take a ${run.unit} from the back of the ${vehicle} [E] and carry it to the green marker [E].` };
    }
    return { title: `Stop ${run.stopIndex}: ${what} left to collect`, text: `Follow the GPS route. Grab a ${run.unit} from the bin [E] and throw it into the back of the ${vehicle} [E].` };
}

function timeline(run) {
    return el('div', { class: 'timeline' }, run.stops.map((stop, index) => el('span', {
        class: `tl${stop.done ? ' is-done' : ''}${!stop.done && index + 1 === run.stopIndex && run.phase === 'stop' ? ' is-current' : ''}`,
    }, el('span'))));
}

function progressRing(done, total) {
    const radius = 100;
    const length = 2 * Math.PI * radius;
    const fill = document.createElementNS(SVG_NS, 'circle');
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 240 240');
    const track = document.createElementNS(SVG_NS, 'circle');
    for (const circle of [track, fill]) {
        circle.setAttribute('cx', '120');
        circle.setAttribute('cy', '120');
        circle.setAttribute('r', String(radius));
    }
    track.setAttribute('class', 'track');
    fill.setAttribute('class', 'fill');
    fill.setAttribute('stroke-dasharray', String(length));
    // start from the previous value, then animate to the new one
    fill.setAttribute('stroke-dashoffset', String(length * (1 - ui.ring)));
    svg.append(track, fill);
    const target = total > 0 ? done / total : 0;
    requestAnimationFrame(() => requestAnimationFrame(() => fill.setAttribute('stroke-dashoffset', String(length * (1 - target)))));
    ui.ring = target;
    return el('div', { class: 'ring' }, svg,
        el('div', { class: 'ring-center' }, el('strong', { text: `${done}/${total}` }), el('small', { text: 'STOPS DONE' })));
}

function renderRun(data) {
    const run = data.run;
    const done = run.phase === 'return' ? run.totalStops : run.stopIndex - 1;
    const step = stepText(run);
    const units = run.phase === 'stop'
        ? el('div', { class: 'units' }, Array.from({ length: run.unitsTotal }, (_, i) => el('span', {
            class: `unit${i < run.unitsDone ? ' is-done' : (i < run.unitsDone + run.inFlight ? ' is-moving' : '')}`,
        }, icon(i < run.unitsDone ? 'check' : (run.jobId === 'recycling' ? 'bag' : 'box')))))
        : null;

    return el('div', { class: 'view' },
        el('div', { class: 'row-between' },
            el('div', {},
                el('div', { class: 'kicker', text: run.phase === 'return' ? 'Return to the Job Center' : 'Working' }),
                el('div', { class: 'title', text: run.label })),
            el('span', { class: 'chip', text: `${data.team.members.length} ON THE JOB` })),
        el('div', { class: 'run' },
            progressRing(done, run.totalStops),
            el('div', {},
                el('div', { class: 'step' },
                    el('div', { class: 'step-title', text: step.title }),
                    el('p', { class: 'step-text', text: step.text }),
                    units),
                timeline(run),
                el('div', { class: 'money-row' },
                    el('div', { class: 'stat' }, el('small', { text: 'EARNED SO FAR (EACH)' }), el('strong', { text: money(run.earned) })),
                    el('div', { class: 'stat' }, el('small', { text: 'FULL ROUTE (EACH)' }), el('strong', { text: money(run.fullPay) }))),
                data.isLeader
                    ? el('div', { class: 'actions' },
                        el('button', {
                            class: 'btn is-primary', type: 'button', disabled: run.phase !== 'return',
                            onclick: (event) => act(event.currentTarget, 'finishJob'),
                        }, icon('flag'), 'Finish & get paid'),
                        el('button', {
                            class: 'btn is-danger', type: 'button',
                            onclick: (event) => act(event.currentTarget, 'cancelJob'),
                        }, 'Cancel job'))
                    : el('p', { class: 'note', text: 'The team leader presses Finish at the Job Center. Everyone is paid at the same time.' }))));
}

// ---------------------------------------------------------------------------
// Frame
// ---------------------------------------------------------------------------

function render() {
    const data = ui.data;
    if (!data) return;
    const mode = `${data.team ? 'team' : 'solo'}:${data.run ? 'run' : 'jobs'}`;
    const animate = mode !== ui.mode;
    ui.mode = mode;
    if (!data.run) ui.ring = 0;

    const team = renderTeam(data);
    const main = data.run ? renderRun(data) : renderJobs(data);
    if (!animate) {
        // same screen, new numbers: skip the entrance animations so nothing jumps
        for (const node of [team, main]) {
            node.classList.remove('view');
            node.querySelectorAll('.slot, .open-team, .job').forEach((child) => { child.style.animation = 'none'; });
        }
    }
    setChildren(document.getElementById('team'), team);
    setChildren(document.getElementById('main'), main);
}

function renderTracker(run) {
    const tracker = document.getElementById('tracker');
    if (!run) { tracker.hidden = true; return; }
    const step = stepText(run);
    setChildren(tracker,
        el('div', { class: 'tracker-head' },
            el('span', { class: 'tracker-icon' }, icon(run.icon)),
            el('span', { class: 'tracker-title' },
                el('strong', { text: run.label }),
                el('small', { text: run.phase === 'return' ? 'RETURN TO JOB CENTER' : `STOP ${run.stopIndex} / ${run.totalStops}` }))),
        el('div', { class: 'tracker-text', text: step.text }),
        run.phase === 'stop' ? el('div', { class: 'tracker-units', text: `${run.units.toUpperCase()} ${run.unitsDone} / ${run.unitsTotal}` }) : null,
        timeline(run));
    tracker.hidden = false;
}

function applyBrand(brand) {
    if (!brand) return;
    document.getElementById('brand-title').textContent = brand.Title;
    document.getElementById('brand-subtitle').textContent = brand.Subtitle;
    document.getElementById('brand-mark').textContent = (brand.Title || 'V').charAt(0);
    const rgb = /^#([0-9a-f]{6})$/i.exec(brand.Accent || '');
    if (!rgb) return;
    const value = parseInt(rgb[1], 16);
    const [r, g, b] = [value >> 16, (value >> 8) & 255, value & 255];
    const root = document.documentElement.style;
    root.setProperty('--accent', brand.Accent);
    root.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, 0.14)`);
    root.setProperty('--accent-line', `rgba(${r}, ${g}, ${b}, 0.5)`);
}

function tickClock() {
    const now = new Date();
    document.getElementById('clock').textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
}

function openPortal(data, brand) {
    applyBrand(brand);
    ui.data = data;
    ui.mode = null;
    document.getElementById('center-label').textContent = data.center || 'Job Center';
    const portal = document.getElementById('portal');
    portal.classList.remove('is-closing');
    portal.hidden = false;
    tickClock();
    render();
}

function hidePortal() {
    const portal = document.getElementById('portal');
    if (portal.hidden || portal.classList.contains('is-closing')) return;
    portal.classList.add('is-closing');
    setTimeout(() => { portal.hidden = true; portal.classList.remove('is-closing'); }, CLOSE_ANIMATION_MS);
}

function closePortal() {
    hidePortal();
    post('close');
}

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    switch (data.action) {
        case 'open': openPortal(data.state, data.brand); break;
        case 'close': hidePortal(); break;
        case 'state':
            ui.data = data.state;
            if (!document.getElementById('portal').hidden) render();
            break;
        case 'tracker': renderTracker(data.tracker); break;
        default: break;
    }
});

document.getElementById('close').addEventListener('click', closePortal);
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !document.getElementById('portal').hidden) closePortal();
});
setInterval(tickClock, 10000);

// ---------------------------------------------------------------------------
// Browser preview (sample data; does nothing in-game)
// ---------------------------------------------------------------------------

const PREVIEW_JOBS = [
    { id: 'delivery', label: 'Delivery', icon: 'box', stops: 5, payPerStop: 350, routeBonus: 500, unit: 'box', units: 'boxes', description: 'Drive the box van to shops around the city and carry the boxes to their back doors.' },
    { id: 'recycling', label: 'Recycling', icon: 'recycle', stops: 5, payPerStop: 300, routeBonus: 500, unit: 'bag', units: 'bags', description: 'Drive the recycling truck to bins around the city and throw the bags into the back.' },
];
const PREVIEW_BASE = { me: 2, maxSize: 4, deposit: 250, bonus: { 1: 100, 2: 115, 3: 130, 4: 150 }, jobs: PREVIEW_JOBS, center: 'Job Center' };
const PREVIEW_TEAM = { id: 3, leader: 2, busy: false, members: [{ id: 2, name: 'Rover Dev', leader: true }, { id: 7, name: 'Mia Tanaka', leader: false }] };
const PREVIEW_RUN = {
    jobId: 'delivery', label: 'Delivery', icon: 'box', unit: 'box', units: 'boxes', pickup: 'vehicle', drop: 'stop', phase: 'stop',
    stopIndex: 3, totalStops: 5, stops: [{ done: true }, { done: true }, { done: false }, { done: false }, { done: false }],
    unitsDone: 1, unitsTotal: 3, inFlight: 1, earned: 805, fullPay: 2587,
};

const Preview = {
    home: { ...PREVIEW_BASE, openTeams: [{ id: 3, leader: 'Rover Dev', size: 2 }, { id: 5, leader: 'Sam Rivera', size: 3 }] },
    team: { ...PREVIEW_BASE, team: PREVIEW_TEAM, isLeader: true },
    run: { ...PREVIEW_BASE, team: { ...PREVIEW_TEAM, busy: true }, isLeader: true, run: PREVIEW_RUN },

    respond(endpoint, data) {
        if (endpoint === 'request') return Promise.resolve({ ok: true, message: `(preview) ${data.action}` });
        return Promise.resolve({ ok: true });
    },

    start() {
        document.body.classList.add('is-preview');
        const page = (location.hash || '#home').slice(1);
        if (page === 'tracker') { renderTracker(PREVIEW_RUN); return; }
        openPortal(Preview[page] || Preview.home, { Title: 'VANGUARD', Subtitle: 'JOBS', Accent: '#10b981' });
    },
};

if (!IS_GAME) {
    Preview.start();
    window.addEventListener('hashchange', () => Preview.start());
}
