const Bundler = require('parcel-bundler');
const express = require('express');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const db = new sqlite3.Database('todos.db');

db.serialize(() => db.run('create table if not exists todos (title varchar(500), completed boolean default 0);'));

app.use(express.json());

const handleError = (res, err, continuation) => {
    if (err !== null) { return res.status(500).json(err); }

    continuation();
};

app.get('/todos', (_req, res) => {
    db.all('select rowid as id, title, completed from todos;', (err, data) => {
        handleError(res, err, () => {
            const todos = data.map((row) => { return { id: row.id, title: row.title, completed: row.completed === 1 } });
            setTimeout(res.json.bind(res, todos), 500);
        });
    });
});

app.post('/todos', (req, res) => {
    db.run('insert into todos (title) values (?)', [req.query.title], 
        (err) => handleError(res, err, () => setTimeout(res.send.bind(res), 250)));
});

app.post('/todos/:id', (req, res) => {
    let completed;
    if (req.query.completed === "true") {
        completed = 1;
    } else if (req.query.completed === "false") {
        completed = 0;
    } else {
        return res.status(422).json({ status: 'error' });
    }

    db.run('update todos set completed = ? where rowid = ?', [completed, req.params.id], (err) => {
        handleError(res, err, () => setTimeout(res.json.bind(res, this.changes), 250));
    });
});

const file = 'index.html';
const options = {};
const bundler = new Bundler(file, options);
app.use(bundler.middleware());

app.listen(8080);