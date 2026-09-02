// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root for license information.

using System.Threading.Tasks;
using Marketplace.SaaS.Accelerator.Services.Models;

namespace Marketplace.SaaS.Accelerator.Services.Contracts;

/// <summary>
/// Server-to-server client for Clavi Mining's own backend (server-api-ts), used
/// only for the duplicate-subscription check on the landing page. Not related to
/// the Azure Marketplace Fulfillment API (<see cref="IFulfillmentApiService"/>).
/// </summary>
public interface IClaviMiningInternalApiService
{
    /// <summary>
    /// Checks whether the given Entra organization already has an active, paid
    /// Clavi Mining subscription. Best-effort: on any failure (misconfiguration,
    /// network error, non-success response), returns a "no duplicate" result
    /// rather than throwing — this check must never block a legitimate purchase
    /// just because it couldn't reach the backend.
    /// </summary>
    Task<DuplicateSubscriptionCheckResult> CheckForDuplicateSubscriptionAsync(string entraTenantId);
}
