import cherrypy

class Root(object):

    @cherrypy.expose
    def index(self):
        return 'Test OK'

    @cherrypy.expose
    def error(self):
        raise Exception('Invalid page')

#NOTE You can connect to this socket by one of the following ways:
#  - curl --unix-socket /tmp/test http://abc/
#  - ssh host -L 1234:/tmp/test; firefox http://localhost:1234/
config = {
    'server.socket_file': '/tmp/test'
}
cherrypy.config.update(config)
cherrypy.tree.mount(Root())
cherrypy.engine.signals.subscribe()
cherrypy.engine.start()
cherrypy.engine.block()
