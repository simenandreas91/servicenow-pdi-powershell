(function verifyRoutingAndCounts() {
  var expected = {
    employee: { knowledgeBase: '6b013e2260890f503614b319a5d63a2d', category: '50ff2a25646d0b103614933ef8ef9c98', count: 142, name: 'Employee' },
    personal: { knowledgeBase: '6b013e2260890f503614b319a5d63a2d', category: '14ff2ee1646d0b103614933ef8ef9c56', count: 142, name: 'Personal' },
    'leadership-portal': { knowledgeBase: 'bd43603f89a68b10b214e1134ad253e2', category: 'de43ec3be4228b10d8cbab474fd09805', count: 65, name: 'Leadership Portal' },
    'personal-offshore': { knowledgeBase: '0643a03f89a68b10b214e1134ad2531d', category: '9a43ec3be4228b10d8cbab474fd0980c', count: 146, name: 'Personal Offshore' }
  };
  var result = { passed: true, handbooks: {}, syncRouting: {} };
  for (var slug in expected) {
    if (!expected.hasOwnProperty(slug)) {
      continue;
    }
    var count = 0;
    var mismatched = 0;
    var grArticle = new GlideRecord('kb_knowledge');
    grArticle.addQuery('u_compendia_page_id', 'STARTSWITH', slug + ':');
    grArticle.query();
    while (grArticle.next()) {
      count++;
      if (grArticle.getValue('kb_knowledge_base') !== expected[slug].knowledgeBase ||
          grArticle.getValue('kb_category') !== expected[slug].category) {
        mismatched++;
      }
    }
    var passed = count === expected[slug].count && mismatched === 0;
    result.handbooks[slug] = { count: count, expectedCount: expected[slug].count, mismatched: mismatched, passed: passed };
    if (!passed) {
      result.passed = false;
    }
  }

  var sync = new VECompendiaKnowledgeSync();
  for (var routingSlug in expected) {
    if (!expected.hasOwnProperty(routingSlug)) {
      continue;
    }
    var handbook = { slug: routingSlug, name: expected[routingSlug].name };
    var routedKnowledgeBase = String(sync.getKnowledgeBaseSysId(routingSlug));
    var routedCategoryRecord = sync.getHandbookCategory(handbook, routedKnowledgeBase);
    var routedCategory = routedCategoryRecord ? String(routedCategoryRecord.getUniqueValue()) : '';
    var routingPassed = routedKnowledgeBase === expected[routingSlug].knowledgeBase && routedCategory === expected[routingSlug].category;
    result.syncRouting[routingSlug] = { passed: routingPassed };
    if (!routingPassed) {
      result.passed = false;
    }
  }
  gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
})();
