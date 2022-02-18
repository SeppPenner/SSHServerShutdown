// --------------------------------------------------------------------------------------------------------------------
// <copyright file="Config.cs" company="Hämmer Electronics">
//   Copyright (c) All rights reserved.
// </copyright>
// <summary>
//   The configuration class.
// </summary>
// --------------------------------------------------------------------------------------------------------------------

namespace SSHServerShutdown;

/// <summary>
/// The configuration class.
/// </summary>
[Serializable]
public class Config
{
    /// <summary>
    /// Gets or sets the server name.
    /// </summary>
    public string ServerName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the server name.
    /// </summary>
    public int ServerPort { get; set; }

    /// <summary>
    /// Gets or sets the user.
    /// </summary>
    public string User { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the password.
    /// </summary>
    public string Password { get; set; } = string.Empty;
}
