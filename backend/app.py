from flask import Flask, request, redirect, render_template, session
import pyrad.client
import pyrad.packet

app = Flask(__name__)
app.secret_key = 'supersecretkey'

@app.route('/')
def index():
    if 'authenticated' in session:
        return "Zaten kimlik doğrulaması yapıldı."
    return render_template('login.html')

@app.route('/login', methods=['POST'])
def login():
    username = request.form['username']
    password = request.form['password']
    
    # RADIUS Kimlik Doğrulama
    srv = pyrad.client.Client(server="127.0.0.1", secret=b"shared_secret", dict=pyrad.dictionary.Dictionary("/allsafe-cp/radius/dictionary"))
    req = srv.CreateAuthPacket(code=pyrad.packet.AccessRequest, User_Name=username)
    req["User-Password"] = req.PwCrypt(password)
    
    try:
        reply = srv.SendPacket(req)
        if reply.code == pyrad.packet.AccessAccept:
            session['authenticated'] = True
            return redirect('/')
        else:
            return "Kimlik doğrulama başarısız."
    except pyrad.client.Timeout:
        return "RADIUS sunucu zaman aşımı."
    except Exception as e:
        return str(e)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
