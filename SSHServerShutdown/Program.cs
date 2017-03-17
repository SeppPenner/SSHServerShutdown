using System;
using System.IO;
using System.Threading;
using System.Xml.Linq;
using System.Xml.Serialization;
using Renci.SshNet;

namespace SSHServerShutdown
{
    internal static class Program
    {
        private static void Main()
        {
            try
            {
                var config = InitConfiguration(AppDomain.CurrentDomain.BaseDirectory + "Config.xml");
                Console.WriteLine("Konfiguration geladen.");

                using (var client = new SshClient(config.ServerName, config.ServerPort, config.User, config.Password))
                {
                    Shutdown(client);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
            }
        }

        private static void Shutdown(SshClient client)
        {
            client.Connect();
            Console.WriteLine("Prozesse werden beendet");
            client.RunCommand("execute /usr/syno/bin/syno_poweroff_task");
            Thread.Sleep(7000);
            Console.WriteLine("Server wird heruntergefahren");
            client.RunCommand("poweroff");
            client.Disconnect();
            Console.WriteLine("Beliebige Taste drücken, um das Programm zu beenden\n");
            Console.ReadKey();
        }

        private static Config InitConfiguration(string filename)
        {
            try
            {
                var xDocument = XDocument.Load(filename);
                return CreateObjectsFromString<Config>(xDocument);
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.ToString());
                return null;
            }
        }

        private static T CreateObjectsFromString<T>(XDocument xDocument)
        {
            var xmlSerializer = new XmlSerializer(typeof(T));
            return (T) xmlSerializer.Deserialize(new StringReader(xDocument.ToString()));
        }
    }
}