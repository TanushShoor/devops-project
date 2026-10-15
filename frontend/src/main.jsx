import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const API = '/api/assignments';
const today = new Date().toISOString().slice(0, 10);
const prettyDate = (value) => value
  ? new Date(`${value}T00:00:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  : 'No due date';

function App() {
  const [assignments, setAssignments] = useState([]);
  const [stats, setStats] = useState({ total: 0, todo: 0, inProgress: 0, done: 0, dueSoon: 0 });
  const [filter, setFilter] = useState('ALL');
  const [course, setCourse] = useState('ALL');
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function load() {
    try {
      setError('');
      const [list, summary] = await Promise.all([fetch(API), fetch(`${API}/stats`)]);
      if (!list.ok || !summary.ok) throw new Error('Could not load your study plan');
      setAssignments(await list.json());
      setStats(await summary.json());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  const courses = useMemo(() => [...new Set(assignments.map((item) => item.course))].sort(), [assignments]);
  const visible = assignments.filter((item) => (filter === 'ALL' || item.status === filter)
    && (course === 'ALL' || item.course === course));

  async function updateStatus(item) {
    const next = item.status === 'TODO' ? 'IN_PROGRESS' : item.status === 'IN_PROGRESS' ? 'DONE' : 'TODO';
    await fetch(`${API}/${item.id}`, {
      method: 'PUT', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: next }),
    });
    load();
  }

  async function remove(item) {
    await fetch(`${API}/${item.id}`, { method: 'DELETE' });
    load();
  }

  async function create(event) {
    event.preventDefault();
    const values = Object.fromEntries(new FormData(event.currentTarget));
    const response = await fetch(API, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...values, due_date: values.due_date || null }),
    });
    if (!response.ok) { setError('Please check the assignment details and try again.'); return; }
    setShowForm(false);
    load();
  }

  const upcoming = assignments.filter((item) => item.status !== 'DONE' && item.due_date)
    .slice(0, 4);

  return <div className="app">
    <aside className="sidebar">
      <div className="brand"><span className="brand-mark">S</span><div><b>StudySpace</b><small>YOUR STUDY PLANNER</small></div></div>
      <nav><a className="active">▦ <span>Overview</span></a><a>✓ <span>Assignments</span></a><a>◫ <span>My courses</span></a></nav>
      <div className="side-bottom"><div className="upgrade"><strong>Small steps add up.</strong><p>Keep your coursework organized and make time for what matters.</p></div><div className="profile"><div className="avatar">S</div><div><b>My study space</b><small>Student account</small></div></div></div>
    </aside>

    <main className="main">
      <header><div><p className="eyebrow">STUDY SPACE / OVERVIEW</p><h1>Your semester, in focus.</h1><p className="muted">A clear view of what’s due and what you’ve accomplished.</p></div><button className="primary" onClick={() => setShowForm(true)}>＋ Add assignment</button></header>
      {error && <div className="alert">⚠ {error}. Check that the app and database are running, then refresh.</div>}

      <section className="stats">
        <Stat label="All assignments" value={stats.total} icon="▦" />
        <Stat label="To do" value={stats.todo} icon="○" />
        <Stat label="In progress" value={stats.inProgress} icon="◔" />
        <Stat label="Due this week" value={stats.dueSoon} icon="◷" />
      </section>

      <section className="content-grid">
        <div className="panel tasks-panel">
          <div className="panel-head"><div><h2>Coursework</h2><p className="muted">Your assignments, sorted by due date.</p></div><div className="filters">{['ALL', 'TODO', 'IN_PROGRESS', 'DONE'].map((item) => <button key={item} className={filter === item ? 'selected' : ''} onClick={() => setFilter(item)}>{item === 'ALL' ? 'All' : item.replace('_', ' ')}</button>)}</div></div>
          <div className="course-filter"><label htmlFor="course-filter">Course</label><select id="course-filter" value={course} onChange={(event) => setCourse(event.target.value)}><option value="ALL">All courses</option>{courses.map((name) => <option key={name}>{name}</option>)}</select></div>
          {loading ? <div className="empty">Loading your study plan…</div> : <div className="table-wrap"><table><thead><tr><th>Assignment</th><th>Course</th><th>Due date</th><th>Priority</th><th>Status</th><th></th></tr></thead><tbody>{visible.map((item) => <tr key={item.id}><td><div className="task-title"><span className={`dot ${item.status.toLowerCase()}`} /><div><b>{item.title}</b><small>{item.description || 'No notes added'}</small></div></div></td><td>{item.course}</td><td className={item.due_date && item.due_date < today && item.status !== 'DONE' ? 'overdue' : ''}>{prettyDate(item.due_date)}</td><td><span className={`priority ${item.priority.toLowerCase()}`}>{item.priority}</span></td><td><span className={`status ${item.status.toLowerCase()}`}>{item.status.replace('_', ' ')}</span></td><td className="row-actions"><button className="icon-btn" onClick={() => updateStatus(item)} title="Move to next status">↻</button><button className="icon-btn delete-btn" onClick={() => remove(item)} title="Delete assignment">×</button></td></tr>)}</tbody></table>{!visible.length && <div className="empty">No assignments here yet. Add one to get started.</div>}</div>}
        </div>

        <aside className="panel activity"><div className="panel-head"><div><h2>Coming up</h2><p className="muted">Your next deadlines.</p></div></div>{upcoming.length ? upcoming.map((item) => <div className="activity-row" key={item.id}><span className="activity-icon">◷</span><div><b>{item.title}</b><small>{item.course} · {prettyDate(item.due_date)}</small></div></div>) : <div className="empty compact">No upcoming deadlines. Enjoy the breathing room.</div>}<div className="study-note"><strong>A little progress today</strong><p>Choose one assignment and take the next small step.</p></div></aside>
      </section>

      {showForm && <div className="modal-backdrop"><form className="modal" onSubmit={create}><div className="modal-head"><div><p className="eyebrow">NEW COURSEWORK</p><h2>Add an assignment</h2></div><button type="button" className="close" onClick={() => setShowForm(false)}>×</button></div><label>Assignment title<input name="title" required maxLength="200" placeholder="e.g. Biology lab report" /></label><label>Course<input name="course" required maxLength="120" placeholder="e.g. Biology 101" /></label><label>Notes<textarea name="description" maxLength="2000" placeholder="What do you need to remember?" /></label><div className="form-row"><label>Due date<input name="due_date" type="date" min="2000-01-01" /></label><label>Priority<select name="priority"><option>LOW</option><option selected>MEDIUM</option><option>HIGH</option></select></label></div><button className="primary full">Save assignment</button></form></div>}
    </main>
  </div>;
}

function Stat({ label, value, icon }) {
  return <div className="stat"><div className="stat-icon">{icon}</div><div><small>{label}</small><strong>{value}</strong><span>In your study plan</span></div></div>;
}

createRoot(document.getElementById('root')).render(<App />);
