CREATE DATABASE avito_social_network;

\connect avito_social_network;

CREATE SCHEMA net;

CREATE TABLE net.UserAccount (
    user_id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_name VARCHAR(255) UNIQUE NOT NULL,
	user_login VARCHAR(30) UNIQUE NOT NULL,
	password_hash VARCHAR(256) NOT NULL,
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE net.Chat (
    chat_id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    chat_name VARCHAR(255) UNIQUE NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE net.ChatUser (
    user_id INT REFERENCES net.UserAccount(user_id) NOT NULL,
    chat_id INT REFERENCES net.Chat(chat_id) NOT NULL,
    CONSTRAINT PK_ChatUser PRIMARY KEY (user_id, chat_id)
);

CREATE TABLE net.Message (
    message_id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    message_text VARCHAR(1000) NOT NULL,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,
    chat_id INT REFERENCES net.Chat(chat_id) NOT NULL,
    user_id INT REFERENCES net.UserAccount(user_id) NOT NULL
);

-- Добавить пользователя
CREATE FUNCTION net.add_user(_user_login VARCHAR(30), _user_name VARCHAR(255), _password_hash VARCHAR(256)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.UserAccount(user_name, user_login, password_hash) VALUES (_user_name, _user_login, _password_hash);
        RETURN currval('net.useraccount_user_id_seq');
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Создать чат между пользователями
CREATE FUNCTION net.add_chat(_chat_name VARCHAR(255), users INT[]) RETURNS INT AS
    $$
    DECLARE inserted_id INT;
    BEGIN
        INSERT INTO net.Chat(chat_name) VALUES (_chat_name);
        inserted_id := currval('net.chat_chat_id_seq');
        INSERT INTO net.ChatUser(chat_id, user_id) SELECT inserted_id, unnest(users);
        RETURN inserted_id;
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

SELECT * FROM net.chat;

-- Добавить пользователя в чат
CREATE PROCEDURE net.add_chat_member(_user_id INT, _chat_id INT) AS
    $$
    BEGIN
        INSERT INTO net.ChatUser(user_id, chat_id) VALUES (_user_id, _chat_id);
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Является ли пользователь участником чата
CREATE OR REPLACE FUNCTION Net.user_in_chat(_user_login VARCHAR(30), _chat_id INT) RETURNS BOOLEAN AS
    $$
    DECLARE
        _user_id INT := (SELECT user_id FROM net.UserAccount WHERE _user_login = user_login);
    BEGIN
        IF _user_id IN (SELECT user_id FROM net.ChatUser WHERE chat_id = _chat_id) THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        end if;
    END;
    $$ LANGUAGE plpgsql;

SELECT * FROM net.ChatUser;
SELECT * FROM net.UserAccount;

SELECT Net.user_in_chat('ann', 1);

-- получить id пользователя по логину
CREATE OR REPLACE FUNCTION net.get_user_id(_user_login VARCHAR(30)) RETURNS INT AS
    $$
    BEGIN
        RETURN (SELECT user_id FROM Net.UserAccount WHERE user_login = _user_login);
    END;
    $$ LANGUAGE plpgsql;

SELECT net.get_user_id('ivan3');

-- Отправить сообщение в чат
CREATE FUNCTION net.send_message(_user_id INT, _chat_id INT, _message VARCHAR(1000)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.Message(message_text, chat_id, user_id) VALUES (_message, _chat_id, _user_id);
        RETURN currval('net.message_message_id_seq');
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

SELECT net.add_user('ivan', 'Иван', 'pass');
SELECT net.add_user('s11', 'Сергей', 'pass');
SELECT net.add_user('dima', 'Дмитрий', 'pass');
SELECT net.add_user('ann', 'Анна', 'pass');
SELECT net.add_user('m11', 'Мария', 'pass');

SELECT net.add_chat('Переговорная1', '[1, 3]');
SELECT net.add_chat('О моде', '[4, 5]');
CALL net.add_chat_member(2, 1);
SELECT net.add_chat('Обший', '[1, 2, 3, 4, 5]');

SELECT net.send_message(1, 1, 'Всем Привет!');
SELECT net.send_message(2, 1, 'Сегодня мы обсудим..');

SELECT net.send_message(4, 2, 'Такс');
SELECT net.send_message(4, 2, 'Приветики');
SELECT net.send_message(5, 2, 'Все завтра!');
SELECT net.send_message(4, 2, 'Но почему..');
SELECT net.send_message(5, 3, 'Итак...');
SELECT net.send_message(2, 1, 'Баг');
SELECT net.add_chat('Свободное общение', '[1, 3, 4]');
SELECT net.send_message(3, 4, 'Привет');

SELECT * FROM json_array_elements('[1, 2, 8]') AS users
    WHERE users::text::int NOT IN (SELECT user_id FROM net.UserAccount)

-- Возвращает хеш от пароля пользователя
CREATE OR REPLACE FUNCTION Net.get_password_hash(_user_login VARCHAR(30)) RETURNS VARCHAR(256) AS
    $$
    BEGIN
        RETURN (SELECT password_hash FROM net.UserAccount WHERE user_login = _user_login);
    END;
    $$ LANGUAGE plpgsql;

-- Список чатов, отсортированные по времени создания последнего сообщения в чате
CREATE OR REPLACE FUNCTION net.get_user_chats(_user_id INT) RETURNS TABLE(json_values json) AS
    $$
    BEGIN
        RETURN QUERY (
        SELECT json_build_object(
            'chat_id', C.chat_id,
            'chat_name', C.chat_name,
            'created_at', C.created_at)
        FROM net.ChatUser AS CU
            JOIN net.Chat AS C ON CU.chat_id = C.chat_id AND CU.user_id = _user_id
        ORDER BY (SELECT MAX(M.created_at) FROM net.Message AS M WHERE M.chat_id = C.chat_id GROUP BY M.chat_id) DESC);
    END;
    $$ LANGUAGE plpgsql;

SELECT net.get_user_chats(4);


-- список сообщений в конкретном чате
CREATE OR REPLACE FUNCTION net.get_messages(_chat_id INT) RETURNS TABLE(json_values json) AS
    $$
    BEGIN
        RETURN QUERY (
            SELECT json_build_object(
                'user', json_build_object(
                    'user_id', M.user_id,
                    'user_name', U.user_name),
                'message_id', M.message_id,
                'message_text', M.message_text,
                'created_at', M.created_at)
            FROM net.Message AS M
                JOIN net.UserAccount AS U ON M.user_id = U.user_id
            WHERE M.chat_id = _chat_id
               ORDER BY M.created_at DESC
        );
    END;
    $$ LANGUAGE plpgsql;

SELECT net.get_messages(2);

SELECT json_build_object(
    'user', json_build_object(
            'user_id', M.user_id,
            'user_name', U.user_name),
    'message_id', M.message_id,
    'message_text', M.message_text,
    'created_at', M.created_at)
FROM net.Message AS M
    JOIN net.UserAccount AS U ON M.user_id = U.user_id
    WHERE M.chat_id = 1
ORDER BY M.created_at DESC;
