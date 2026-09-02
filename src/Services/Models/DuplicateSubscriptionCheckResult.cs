// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root for license information.

using System.Text.Json.Serialization;

namespace Marketplace.SaaS.Accelerator.Services.Models;

/// <summary>
/// Result of asking Clavi Mining's own backend whether a purchaser's organization
/// already has an active, paid subscription (see
/// GET /internal/marketplace/tenant/duplicate-subscription-check on server-api-ts).
/// </summary>
public class DuplicateSubscriptionCheckResult
{
    /// <summary>Whether a Clavi Mining tenant exists at all for this Entra org.</summary>
    [JsonPropertyName("exists")]
    public bool Exists { get; set; }

    /// <summary>
    /// Whether that tenant already has an active, non-FREE subscription. FREE-plan
    /// tenants don't count — buying through Marketplace is how they'd upgrade.
    /// </summary>
    [JsonPropertyName("has_active_subscription")]
    public bool HasActiveSubscription { get; set; }

    /// <summary>The tenant's admin email, if one could be found. Null if not applicable.</summary>
    [JsonPropertyName("admin_email")]
    public string AdminEmail { get; set; }
}
