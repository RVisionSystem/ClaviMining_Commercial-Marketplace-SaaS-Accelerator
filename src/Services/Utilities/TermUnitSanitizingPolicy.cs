// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE file in the project root for license information.

using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Azure.Core;
using Azure.Core.Pipeline;

namespace Marketplace.SaaS.Accelerator.Services.Utilities;

/// <summary>
/// Marketplace subscriptions in a free trial report their trial length as a day-based
/// ISO-8601 term (e.g. "P7D" for a 7-day trial) in the "termUnit" field of Fulfillment
/// API responses. The Microsoft.Marketplace.SaaS SDK's TermUnitEnum only recognizes
/// P1M/P1Y/P2Y/P3Y/P4Y/P5Y and throws while deserializing anything else, which crashes
/// the landing page for any customer currently in a day-based free trial. This policy
/// rewrites unsupported day-based termUnit values to "P1M" before the SDK parses the
/// response body, since the transient trial-term value isn't used for billing math
/// (the plan's own recurring billing term drives that).
/// </summary>
public class TermUnitSanitizingPolicy : HttpPipelineSynchronousPolicy
{
    private static readonly Regex DayTermUnitPattern = new(@"""termUnit""\s*:\s*""P\d+D""", RegexOptions.Compiled);

    public override void OnReceivedResponse(HttpMessage message)
    {
        var response = message.Response;
        if (response.ContentStream == null || response.ContentStream.Length == 0)
        {
            return;
        }

        string body;
        using (var reader = new StreamReader(response.ContentStream, Encoding.UTF8))
        {
            body = reader.ReadToEnd();
        }

        if (!DayTermUnitPattern.IsMatch(body))
        {
            response.ContentStream = new MemoryStream(Encoding.UTF8.GetBytes(body));
            return;
        }

        var sanitized = DayTermUnitPattern.Replace(body, "\"termUnit\":\"P1M\"");
        response.ContentStream = new MemoryStream(Encoding.UTF8.GetBytes(sanitized));
    }
}
