import os
import sys
from flask import Flask, request, jsonify, abort
from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy import create_engine, sql
from collections import namedtuple
from flask_httpauth import HTTPBasicAuth
from collections import namedtuple


class SocialNetworkHTTPBasicAuth(HTTPBasicAuth):
    def __init__(self, scheme=None, realm=None):
        super(SocialNetworkHTTPBasicAuth, self).__init__(scheme or 'Basic', realm)

    def user_id(self) -> [int, None]:
        if not request.authorization:
            return None
        return db.execute(sql.text('SELECT net.get_user_id(:login);'), login=self.username()).scalar()

    def user_in_chat(self, chat_id):
        sql_query = sql.text('SELECT Net.user_in_chat(:user_id, :chat_id);')
        user_in_chat = db.execute(sql_query, user_id=self.user_id, chat_id=chat_id).scalar()
        if not user_in_chat:
            abort(403)


app = Flask(__name__)
app.config.from_object('config.Config')
db = create_engine(app.config['DATABASE_URI'])
auth = SocialNetworkHTTPBasicAuth()

sys.path.append(os.getcwd() + '/code')


@auth.verify_password
def verify_password(username, password):
    query = sql.text('SELECT Net.get_password_hash(:login)')
    result = db.execute(query, login=username).scalar()
    if result is None or not check_password_hash(result, password):
        return False
    return True


@app.route('/hello')
@auth.login_required
def hello():
    print(auth.user_id())
    return 'hellom world!'


@app.route('/users', methods=['POST'])
def add_user():
    values = request.get_json()
    if (user_login := values.get('user_login')) is None:
        return {}, 400
    if (user_name := values.get('user_name')) is None:
        return {}, 400
    if (password := values.get('password')) is None:
        return {}, 400
    query = sql.text('SELECT net.add_user(:login, :name, :passwd);')
    with db.begin() as conn:
        result = conn.execute(query, login=user_login, name=user_name, passwd=generate_password_hash(password)).scalar()
    return jsonify(data=result), 201


@app.route('/users/<user_id>', methods=['GET'])
@auth.login_required
def user_data(user_id):
    if user_id == auth.user_id():
        return {}
    else:
        return {}


@app.route('/chats', methods=['POST'])
@auth.login_required
def add_chat():
    current_user = auth.user_id()
    values = request.get_json()
    if (chat_name := values.get('chat_name')) is None:
        return {}, 400
    if (users := values.get('users')) is None:
        return {}, 400
    users.append(current_user)
    query = sql.text('SELECT net.add_chat(:name, :users);')
    with db.begin() as conn:
        result = conn.execute(query, name=chat_name, users=users).scalar()
    return jsonify(data=result), 201


@app.route('/chats/<int:chat_id>', methods=['POST'])
@auth.login_required
def add_chat_member(chat_id):
    auth.user_in_chat(chat_id)
    values = request.get_json()
    if (user_id := values.get('user_id')) is None:
        return {}, 400
    query = sql.text('CALL net.add_chat_member(:user_id, :chat_id);')
    with db.begin() as conn:
        conn.execute(query, user_id=user_id, chat_id=chat_id).scalar()
    return {}, 201


@app.route('/users/<int:user_id>/chats', methods=['GET'])
@auth.login_required
def get_user_chats(user_id):
    if user_id != auth.user_id():
        abort(403)
    query = sql.text('SELECT net.get_user_chats(:user_id);')
    result = db.execute(query, user_id=user_id)
    if result.fetchone() is None:
        return {}, 400
    return jsonify([i[0] for i in result.fetchall()]), 200


@app.route('/chats/<int:chat_id>/messages', methods=['POST', 'GET'])
@auth.login_required
def send_message(chat_id):
    auth.user_in_chat(chat_id)
    if request.method == 'POST':
        values = request.get_json()
        if (message_text := values.get('message_text')) is None:
            return {}, 400
        query = sql.text('SELECT net.send_message(:user_id, :chat_id, :text);')
        with db.begin() as conn:
            result = conn.execute(query, user_id=auth.user_id(), chat_id=chat_id, text=message_text).scalar()
        return jsonify(data=result), 201
    elif request.method == 'GET':
        query = sql.text('SELECT net.get_messages(:chat_id);')
        result = db.execute(query, chat_id=chat_id)
        if result.fetchone() is None:
            return {}, 400
        return jsonify([i[0] for i in result.fetchall()]), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9080)
