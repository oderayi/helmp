// module.exports = {
//     //endpoint: 'https://github.com/mojaloop',
//     token: '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',
//     platform: 'github',
//     onboardingConfig: {
//       extends: ['config:recommended'],
//     },
//     repositories: ['mojaloop/helm'],
// };

module.exports = {
    platform: 'local',
    // onboardingConfig: {
    //   extends: ['config:recommended'],
    // },
    packageRules: [
        {
          matchPackagePatterns: [
            "*"
          ],
          matchUpdateTypes: [
            "major",
            "minor",
            "patch"
          ],
          groupName: "all dependencies",
          groupSlug: "all-deps"
        }
    ]
};