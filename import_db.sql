PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS question_likes;
DROP TABLE IF EXISTS question_follows;
DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id PRIMARY KEY NOT NULL,
    fname VARCHAR(255) NOT NULL,
    lname VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
    id PRIMARY KEY NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,

    author_id INTEGER,
    FOREIGN KEY(author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
    question_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY(question_id) REFERENCES questions(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE replies (
    id PRIMARY KEY NOT NULL,
    body TEXT NOT NULL,

    reply_id INTEGER,
    question_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY(reply_id) REFERENCES replies(id)
    FOREIGN KEY(question_id) REFERENCES questions(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
    question_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    FOREIGN KEY(question_id) REFERENCES questions(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

/* Seed the datas */

INSERT INTO users
    ('id', 'fname', 'lname')
VALUES
    (1, 'Drew', 'Rodrigues'), (2, 'Jason', 'Fu');

INSERT INTO questions
    ('id', 'title', 'body', 'author_id')
VALUES
    (1, 'Ask whatever question you want?', 'Whatevs man', 1),
    (2, 'Hello? Hello?', 'Hey man', 2);

INSERT INTO question_follows
    ('question_id', 'user_id')
VALUES
    (1, 2), (2, 1), (1, 1);

INSERT INTO replies
    ('id', 'body', 'reply_id', 'question_id', 'user_id')
VALUES
    (1, 'What are you talking about?', NULL, 1, 2),
    (2, 'I''m a subreply', 1, 1, 2);

INSERT INTO question_likes
    ('question_id', 'user_id')
VALUES
    (1, 1);