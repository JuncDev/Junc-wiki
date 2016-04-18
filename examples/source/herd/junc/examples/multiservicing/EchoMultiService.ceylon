import herd.junc.api {
	Junc,
	ServiceAddress,
	MultiService,
	JuncTrack,
	JuncSocket,
	Station,
	JuncService,
	Promise,
	TimeEvent,
	PeriodicTimeRow,
	Timer
}
import herd.junc.core {
	startJuncCore,
	Railway,
	JuncOptions,
	LogWriter
}
import herd.junc.api.monitor {
	Counter,
	Average,
	Meter,
	Priority
}


shared void runEchoMultiService() {
	// starting Junc
	print( "Start Junc" );
	startJuncCore (
		JuncOptions {
			monitorPeriod = 2;
			optimizationPeriodInCycles = 10;
			timeLimit = 50;
			coreFactor = 2.0;
		}
	).onComplete (
		// listen the Junc is started
		(Railway railway) {
			// writing log
			railway.addLogWriter (
				object satisfies LogWriter {
					shared actual void writeLogMessage (
						String identifier,
						Priority priority,
						String message,
						Throwable? throwable
					) {
						String str = if ( exists t = throwable ) then " with error ``t.message```" else "";
						print( "``priority``: ``identifier`` sends '``message``'``str``" );
					}
				}
			);
			// writing metrics
			railway.addMetricWriter(PerformanceMetricWriter());
			// deploying echo station
			railway.deployStation(EchoMultiStation(railway, 2000)).onError (
				(Throwable reason) => print("error while deploying echo multi station ``reason``")
			);
		}
	);
}


class EchoMultiStation(Railway railway, Integer totalSockets) satisfies Station
{

	String scoketsNumber = "socketsNumber";
	String responseRate = "responseRate";
	String serverRate = "serverRate";
	String messageRate = "messageRate";
	
	// address implementing echo service has to listen to
	ServiceAddress echoAddress = ServiceAddress("echo multi service");
	

	shared actual Promise<Object> start(JuncTrack track, Junc junc) {
		EchoMultiService multiService = EchoMultiService (
			junc.monitor.meter(messageRate), junc.monitor.average(serverRate), junc, echoAddress, 0
		);
		
		EchoMultiServiceStation service = EchoMultiServiceStation (
			railway, totalSockets, track, junc,
			junc.monitor.counter(scoketsNumber), junc.monitor.average(responseRate),
			multiService, echoAddress
			
		);
		return service.start();
	}

}

class EchoMultiServiceStation (
	Railway railway,
	Integer totalSockets, JuncTrack track, Junc junc,
	Counter sockets, Average response,
	EchoMultiService multiService,
	ServiceAddress echoAddress
) {
	
	variable Boolean stopMessaging = false;
	variable Integer numberOfSockets = 0;

	variable Timer? timer = null;
	
		
	void onEchoClient(JuncSocket<Integer, Integer> socket) {
		sockets.increment();
		numberOfSockets ++;
		socket.onData (
			(Integer timeStamp) {
				response.sample((system.milliseconds - timeStamp).float);
				if (stopMessaging && numberOfSockets > 20) {
					numberOfSockets --;
					socket.close();
				}
				else {
					socket.publish(system.milliseconds);
					if ( stopMessaging && !timer exists ) {
						// close the Junc after 10 seconds
						Timer t = track.createTimer(PeriodicTimeRow(10000, 1));
						timer = t;
						t.onClose(railway.stop);
						t.start();
					}
				}
			}
		);
		socket.onClose(sockets.decrement);
		socket.publish(system.milliseconds);
	}
	
	// station start method
	shared Promise<Object> start() {
		return multiService.registerService(track.context).onComplete (
			// service registration handler
			(JuncService<Integer, Integer> service) {
				value timer = track.createTimer(PeriodicTimeRow(250, totalSockets / 25));
				timer.onData (
					(TimeEvent event) {
						for (i in 0:25) {
							track.connect<Integer, Integer, ServiceAddress>(echoAddress)
									.onComplete(onEchoClient);
						}
					}
				);
				timer.onClose (
					() {
						value timerStopping = track.createTimer(PeriodicTimeRow(10000, 1));
						timerStopping.onClose(() => stopMessaging = true);
						timerStopping.start();
					}
				);
				timer.start();
			},
			(Throwable err) => print("service registration error ``err``")
		);
	}
}



class EchoMultiService(
	Meter messages, Average responseServer, Junc junc, ServiceAddress address, Integer serviceNumberLimit
)
		extends MultiService<Integer, Integer, ServiceAddress>(junc, address, serviceNumberLimit)
{
	shared actual class ServiceHandler(JuncTrack track)
			 extends super.ServiceHandler(track)
	{
		shared actual void connected(JuncSocket<Integer, Integer> socket) {
			socket.onData (
				(Integer timeStamp) {
					for (i in 0 : 200000) {}
					messages.tick();
					responseServer.sample((system.milliseconds - timeStamp).float);
					socket.publish(timeStamp);
				}
			);
		}
	}
}
