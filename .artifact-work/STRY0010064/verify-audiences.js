(function verifyAudiences() {
  var bases = {
    employeeAndPersonal: '6b013e2260890f503614b319a5d63a2d',
    leadership: 'bd43603f89a68b10b214e1134ad253e2',
    offshore: '0643a03f89a68b10b214e1134ad2531d'
  };
  var roleName = 'sn_mh.manager_hub_user';

  function hasRole(userSysId, requiredRoleName) {
    return GlideUser.getUserByID(userSysId).hasRole(requiredRoleName);
  }

  function findPersona(contractType, manager) {
    var grProfile = new GlideRecord('sn_hr_core_profile');
    grProfile.addQuery('active', true);
    grProfile.addQuery('u_contract_type', contractType);
    grProfile.addQuery('user.active', true);
    grProfile.addNotNullQuery('user');
    grProfile.orderBy('user');
    grProfile.query();
    while (grProfile.next()) {
      var userSysId = grProfile.getValue('user');
      var elevated = hasRole(userSysId, 'admin') || hasRole(userSysId, 'knowledge_admin') || hasRole(userSysId, 'knowledge');
      if (!elevated && hasRole(userSysId, roleName) === manager) {
        return userSysId;
      }
    }
    throw 'No active persona found for contract type ' + contractType + ', manager=' + manager;
  }

  function getPublishedArticle(knowledgeBaseSysId) {
    var grArticle = new GlideRecord('kb_knowledge');
    grArticle.addQuery('kb_knowledge_base', knowledgeBaseSysId);
    grArticle.addQuery('workflow_state', 'published');
    grArticle.addQuery('active', true);
    grArticle.orderBy('sys_id');
    grArticle.setLimit(1);
    grArticle.query();
    if (!grArticle.next()) {
      throw 'No published article found in knowledge base ' + knowledgeBaseSysId;
    }
    return grArticle.getUniqueValue();
  }

  var samples = {};
  for (var baseName in bases) {
    if (bases.hasOwnProperty(baseName)) {
      samples[baseName] = getPublishedArticle(bases[baseName]);
    }
  }

  var personas = {
    onshoreManager: findPersona('ON', true),
    offshoreManager: findPersona('OFF', true),
    onshoreEmployee: findPersona('ON', false),
    offshoreEmployee: findPersona('OFF', false)
  };
  var expected = {
    onshoreManager: { employeeAndPersonal: true, leadership: true, offshore: false },
    offshoreManager: { employeeAndPersonal: true, leadership: true, offshore: true },
    onshoreEmployee: { employeeAndPersonal: true, leadership: false, offshore: true },
    offshoreEmployee: { employeeAndPersonal: true, leadership: false, offshore: true }
  };
  var result = { passed: true, personas: {} };
  var impersonator = new GlideImpersonate();

  for (var personaName in personas) {
    if (!personas.hasOwnProperty(personaName)) {
      continue;
    }
    var personaResult = { contractType: personaName.indexOf('onshore') === 0 ? 'ON' : 'OFF', manager: personaName.indexOf('Manager') > -1, access: {} };
    try {
      impersonator.impersonate(personas[personaName]);
      var knowledgeSecurity = new KBKnowledge();
      for (var sampleName in samples) {
        if (!samples.hasOwnProperty(sampleName)) {
          continue;
        }
        var grSample = new GlideRecord('kb_knowledge');
        grSample.get(samples[sampleName]);
        var actual = knowledgeSecurity.canRead(grSample) === true;
        personaResult.access[sampleName] = {
          actual: actual,
          expected: expected[personaName][sampleName],
          passed: actual === expected[personaName][sampleName]
        };
        if (!personaResult.access[sampleName].passed) {
          result.passed = false;
        }
      }
    } finally {
      impersonator.unimpersonate();
    }
    result.personas[personaName] = personaResult;
  }

  gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
})();
