Default of Admin Portal only available for minimum setting, if we need  `Auto Active Subscription`, `Metered Billing`. We need to config it before use.


### Auto Active Subscription
* Customer deploy **Saas** in azure portal. 
* The request will have status as **PendingFulfillmentStart**.
* customer configuration `subscribe` request to our service.
* The request will have status change to **PendingActivation** 
* We/Automation need to `active` subscription with manually check in admin portal or just enable **IsAutomaticProvisioningSupported**

In Admin Portal:
Go to 'ApplicationConfig' ➡️ 'IsAutomaticProvisioningSupported' click edit from `false` to `true`
![image01](/ryowa_docs/images/adminPortalConfig-01.png)

### Metered Billing
**NOTE**: only available for **plan** that has metered billing!!
* If our plan need metered billing we have to focus these:
  
![image02](/ryowa_docs/images/adminPortalConfig-02.png)
