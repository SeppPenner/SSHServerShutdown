using System;

namespace SSHServerShutdown
{
    [Serializable]
    public class Config
    {
        public string ServerName { get; set; }

        public int ServerPort { get; set; }

        public string User { get; set; }

        public string Password { get; set; }
    }
}