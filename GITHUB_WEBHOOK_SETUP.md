# GitHub Webhook Setup for Jenkins

This guide will help you configure GitHub to automatically trigger Jenkins builds when you push or merge to the main/master branch.

## Prerequisites

- Jenkins pipeline already created (using the setup scripts)
- Jenkins server accessible from the internet (or use a webhook proxy)
- GitHub repository: `https://github.com/shivain22/keycloak_with_plugins_deploy.git`

## Step 1: Configure Jenkins for GitHub Webhooks

### Option A: Jenkins is publicly accessible

1. Go to your Jenkins job: `http://your-jenkins-server:8080/job/Keycloak-Deployment`
2. Click **Configure**
3. Under **Build Triggers**, check **GitHub hook trigger for GITscm polling**
4. Click **Save**

### Option B: Jenkins is behind a firewall (use webhook proxy)

If your Jenkins is not publicly accessible, you can use:
- [ngrok](https://ngrok.com/) - Free tunnel service
- [GitHub App](https://github.com/apps) - For private Jenkins instances
- Jenkins webhook proxy service

## Step 2: Configure GitHub Webhook

1. Go to your GitHub repository: `https://github.com/shivain22/keycloak_with_plugins_deploy`

2. Click **Settings** → **Webhooks** → **Add webhook**

3. Configure the webhook:
   - **Payload URL**: 
     - If Jenkins is public: `http://your-jenkins-server:8080/github-webhook/`
     - If using ngrok: `https://your-ngrok-url.ngrok.io/github-webhook/`
   - **Content type**: `application/json`
   - **Secret**: (Optional) Leave empty or set a secret and configure it in Jenkins
   - **Which events would you like to trigger this webhook?**: 
     - Select **Just the push event** (recommended)
     - Or **Let me select individual events** → check **Pushes**
   - **Active**: ✓ Checked

4. Click **Add webhook**

## Step 3: Test the Webhook

### Test 1: Manual webhook test
1. In GitHub, go to **Settings** → **Webhooks**
2. Find your webhook and click on it
3. Scroll down and click **Recent Deliveries**
4. Click on the latest delivery to see the response
5. You should see a `200 OK` response

### Test 2: Push to repository
1. Make a small change to your repository (e.g., update README)
2. Commit and push to `main` or `master` branch:
   ```bash
   git add .
   git commit -m "Test Jenkins webhook"
   git push origin main
   ```
3. Check Jenkins dashboard - a new build should start automatically

## Troubleshooting

### Webhook not triggering builds

1. **Check webhook delivery in GitHub**:
   - Go to repository → Settings → Webhooks
   - Click on your webhook → Recent Deliveries
   - Check if requests are being sent (green checkmark = success)
   - If red X, check the error message

2. **Check Jenkins logs**:
   ```bash
   # On Jenkins server
   tail -f /var/log/jenkins/jenkins.log
   ```
   Look for webhook-related errors

3. **Verify Jenkins configuration**:
   - Ensure "GitHub hook trigger for GITscm polling" is enabled
   - Check that the job is not disabled
   - Verify the branch name matches (main or master)

4. **Check network connectivity**:
   - Ensure GitHub can reach your Jenkins server
   - Check firewall rules
   - Verify Jenkins is running

### Common Issues

#### Issue: "403 Forbidden" in webhook delivery
**Solution**: 
- Check if Jenkins requires authentication for webhooks
- Configure webhook authentication in Jenkins
- Or use a webhook secret

#### Issue: "Connection refused" or "Timeout"
**Solution**:
- Jenkins is not accessible from the internet
- Use ngrok or another tunnel service
- Or configure a webhook proxy

#### Issue: Webhook triggers but build doesn't start
**Solution**:
- Check if branch name matches (main vs master)
- Verify "GitHub hook trigger" is enabled in job configuration
- Check Jenkins logs for errors

#### Issue: Build starts but fails
**Solution**:
- Check build console output in Jenkins
- Verify Docker is available to Jenkins user
- Check if `.env` file exists or is properly configured
- Ensure `start.sh` is executable

## Alternative: Poll SCM (if webhooks don't work)

If webhooks are not working, you can use SCM polling as a fallback:

1. In Jenkins job configuration, uncheck "GitHub hook trigger"
2. Check "Poll SCM"
3. Set schedule: `H/5 * * * *` (every 5 minutes)
4. This will check for changes every 5 minutes

**Note**: This is less efficient than webhooks but works if Jenkins is not publicly accessible.

## Security Considerations

1. **Use HTTPS**: If possible, use HTTPS for Jenkins webhook endpoint
2. **Webhook Secret**: Set a secret in GitHub and configure it in Jenkins
3. **Restrict Access**: Limit who can trigger builds
4. **Monitor Webhooks**: Regularly check webhook delivery logs

## Verification Checklist

- [ ] GitHub webhook created and active
- [ ] Webhook delivery shows successful (200 OK)
- [ ] Jenkins job has "GitHub hook trigger" enabled
- [ ] Test push triggers a build
- [ ] Build completes successfully
- [ ] `start.sh` runs correctly
- [ ] Keycloak deploys successfully

## Next Steps

After webhook is configured:
1. Make a test commit and push to main/master
2. Verify Jenkins automatically starts a build
3. Monitor the build logs
4. Check that Keycloak deploys correctly

For more information, see:
- [Jenkins GitHub Plugin Documentation](https://plugins.jenkins.io/github/)
- [GitHub Webhooks Documentation](https://docs.github.com/en/developers/webhooks-and-events/webhooks)



