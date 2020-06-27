CREATE SCHEMA net;

CREATE USER network_user WITH PASSWORD 'pass';
GRANT USAGE ON SCHEMA net TO network_user;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA net TO network_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO network_user;

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

-- Отобразить входящих в чат пользователей
CREATE OR REPLACE FUNCTION net.get_chat_members(_chat_id INT) RETURNS TABLE(j_values json) AS
    $$
    BEGIN
        RETURN QUERY (
        WITH members AS (
            SELECT json_agg(
                   json_build_object(
                           'user_id', U.user_id,
                           'user_name', U.user_name)) members
            FROM net.chatuser AS CU
                JOIN net.useraccount AS U ON CU.user_id = U.user_id AND CU.chat_id = _chat_id
        )
        SELECT
            json_build_object(
            'chat_id', C.chat_id,
            'chat_name', C.chat_name,
            'members', (SELECT M.members FROM members AS M))
        FROM net.chat AS C
            WHERE C.chat_id = _chat_id);
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Добавить пользователя
CREATE FUNCTION net.add_user(_user_login VARCHAR(30), _user_name VARCHAR(255), _password_hash VARCHAR(256)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.UserAccount(user_name, user_login, password_hash) VALUES (_user_name, _user_login, _password_hash);
        RETURN currval('net.useraccount_user_id_seq');
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Создать чат между пользователями
CREATE OR REPLACE FUNCTION net.add_chat(_chat_name VARCHAR(255), users INT[]) RETURNS INT AS
    $$
    DECLARE inserted_id INT;
    BEGIN
        IF EXISTS(SELECT unnest(users) EXCEPT SELECT user_id FROM net.useraccount) THEN
            RETURN NULL;
        END IF;
        INSERT INTO net.Chat(chat_name) VALUES (_chat_name);
        inserted_id := currval('net.chat_chat_id_seq');
        INSERT INTO net.ChatUser(chat_id, user_id) SELECT inserted_id, unnest(users);
        RETURN inserted_id;
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Добавить пользователя в чат
CREATE OR REPLACE FUNCTION net.add_chat_member(_user_id INT, _chat_id INT) RETURNS TABLE(j_values json) AS
    $$
    BEGIN
        IF _user_id NOT IN (SELECT user_id FROM net.useraccount) OR
           _chat_id NOT IN (SELECT chat_id FROM net.chat) THEN
            RETURN QUERY (SELECT CAST(NULL AS json));
        ELSE
            INSERT INTO net.ChatUser(user_id, chat_id) VALUES (_user_id, _chat_id);
            RETURN QUERY (SELECT net.get_chat_members(_chat_id));
        END IF;
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Является ли пользователь участником чата
CREATE OR REPLACE FUNCTION Net.user_in_chat(_user_id INT, _chat_id INT) RETURNS BOOLEAN AS
    $$
    BEGIN
        IF _user_id IN (SELECT user_id FROM net.ChatUser WHERE chat_id = _chat_id) THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        end if;
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- получить id пользователя по логину
CREATE OR REPLACE FUNCTION net.get_user_id(_user_login VARCHAR(30)) RETURNS INT AS
    $$
    BEGIN
        RETURN (SELECT user_id FROM Net.UserAccount WHERE user_login = _user_login);
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Отправить сообщение в чат
CREATE FUNCTION net.send_message(_user_id INT, _chat_id INT, _message VARCHAR(1000)) RETURNS INT AS
    $$
    BEGIN
        INSERT INTO net.Message(message_text, chat_id, user_id) VALUES (_message, _chat_id, _user_id);
        RETURN currval('net.message_message_id_seq');
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Возвращает хеш от пароля пользователя
CREATE OR REPLACE FUNCTION Net.get_password_hash(_user_login VARCHAR(30)) RETURNS VARCHAR(256) AS
    $$
    BEGIN
        RETURN (SELECT password_hash FROM net.UserAccount WHERE user_login = _user_login);
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

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
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

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
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Получить сведения о пользователе
CREATE OR REPLACE FUNCTION net.user_info(_user_id INT) RETURNS TABLE(j_values json) AS
    $$
    BEGIN
        RETURN QUERY (
            SELECT
                json_build_object(
                    'user_id', user_id,
                    'user_name', user_name,
                    'created_at', created_at
                    )
            FROM net.useraccount AS U
            WHERE U.user_id = _user_id
        );
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;

-- Получить сведения о пользователе и списое чатов, в которых он участвует
CREATE OR REPLACE FUNCTION net.self_user_info(_user_id INT) RETURNS TABLE(j_values json) AS
    $$
    BEGIN
        RETURN QUERY (
            WITH Temp_1 AS (
               SELECT
                   U.user_id,
                   json_agg(
                     json_build_object(
                       'chat_id', C.chat_id,
                       'chat_name', C.chat_name,
                       'created_at', C.created_at)) AS jobj
               FROM net.useraccount AS U
                   JOIN net.chatuser AS CU ON U.user_id = _user_id AND U.user_id = CU.user_id
                   JOIN net.chat AS C ON C.chat_id = CU.chat_id
               GROUP BY U.user_id
            )
        SELECT
            json_build_object(
                'user_id', U.user_id,
                'user_name', U.user_name,
                'created_at', U.created_at,
                'chats', COALESCE( (SELECT jobj FROM Temp_1), '[]'))
        FROM net.useraccount AS U
            WHERE U.user_id = _user_id);
    END;
    $$ SECURITY DEFINER SET SEARCH_PATH = public LANGUAGE plpgsql;
