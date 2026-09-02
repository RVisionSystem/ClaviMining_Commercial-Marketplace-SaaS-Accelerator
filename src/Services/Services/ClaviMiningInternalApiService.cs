// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root for license information.

using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Marketplace.SaaS.Accelerator.Services.Contracts;
using Marketplace.SaaS.Accelerator.Services.Models;
using Microsoft.Extensions.Logging;

namespace Marketplace.SaaS.Accelerator.Services.Services;

/// <inheritdoc cref="IClaviMiningInternalApiService"/>
public class ClaviMiningInternalApiService : IClaviMiningInternalApiService
{
    private readonly HttpClient httpClient;

    private readonly string baseUrl;

    private readonly string token;

    private readonly ILogger<ClaviMiningInternalApiService> logger;

    public ClaviMiningInternalApiService(
        HttpClient httpClient,
        string baseUrl,
        string token,
        ILogger<ClaviMiningInternalApiService> logger)
    {
        this.httpClient = httpClient;
        this.baseUrl = baseUrl?.TrimEnd('/');
        this.token = token;
        this.logger = logger;
    }

    /// <inheritdoc/>
    public async Task<DuplicateSubscriptionCheckResult> CheckForDuplicateSubscriptionAsync(string entraTenantId)
    {
        var fallback = new DuplicateSubscriptionCheckResult { Exists = false, HasActiveSubscription = false, AdminEmail = null };

        if (string.IsNullOrWhiteSpace(this.baseUrl) || string.IsNullOrWhiteSpace(this.token) || string.IsNullOrWhiteSpace(entraTenantId))
        {
            this.logger?.LogWarning("ClaviMiningInternalApiService: not configured or no tenant id — skipping duplicate check");
            return fallback;
        }

        try
        {
            var url = $"{this.baseUrl}/internal/marketplace/tenant/duplicate-subscription-check?tid={Uri.EscapeDataString(entraTenantId)}";
            using var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Add("x-internal-token", this.token);

            using var response = await this.httpClient.SendAsync(request).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                this.logger?.LogWarning("ClaviMiningInternalApiService: duplicate check returned {StatusCode}", response.StatusCode);
                return fallback;
            }

            var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
            return JsonSerializer.Deserialize<DuplicateSubscriptionCheckResult>(body) ?? fallback;
        }
        catch (Exception ex)
        {
            // Best-effort by design — see interface doc. A reachability problem here
            // must never block a legitimate new customer from subscribing.
            this.logger?.LogError(ex, "ClaviMiningInternalApiService: duplicate check failed");
            return fallback;
        }
    }
}
