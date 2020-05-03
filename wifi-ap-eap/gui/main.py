import os
import cherrypy
import sqlite3

class Root(object):

    @cherrypy.expose
    def index(self):
        raise cherrypy.InternalRedirect("/static/index.html")

    @cherrypy.expose
    def error(self):
        raise Exception('Invalid page')

    @cherrypy.expose
    @cherrypy.tools.json_out()
    def get_data(self):
        with sqlite3.connect('freeradius.db') as conn:
            conn.row_factory = sqlite3.Row
            c = conn.cursor()
            data = {}
            for table in "radusergroup,radgroupreply,radpostauth,radacct".split(","):
                c.execute("SELECT * FROM " + table)
                data[table] = [dict(row) for row in c]
            return data

#NOTE You can connect to this socket by one of the following ways:
#  - curl --unix-socket /tmp/test http://abc/
#  - ssh host -L 1234:/tmp/test; firefox http://localhost:1234/
config = {
    'server.socket_file': '/tmp/test'
}
cherrypy.config.update(config)
cherrypy.tree.mount(Root(), "/", {
    "/": {
        "tools.staticdir.root": os.path.dirname(os.path.realpath(__file__))
    },
    "/static": {
        "tools.staticdir.on": True,
        "tools.staticdir.dir": "static"
    }
})
cherrypy.engine.signals.subscribe()
cherrypy.engine.start()
cherrypy.engine.block()
