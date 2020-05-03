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

cherrypy.config.update("config")
app = cherrypy.tree.mount(Root(), "/", {
    "/": {
        "tools.staticdir.root": os.path.dirname(os.path.realpath(__file__))
    }
})
app.merge("config")
cherrypy.engine.signals.subscribe()
cherrypy.engine.start()
cherrypy.engine.block()
