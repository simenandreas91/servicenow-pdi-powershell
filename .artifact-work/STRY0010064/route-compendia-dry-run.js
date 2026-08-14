(function dryRun() {
  var targets = {
    'leadership-portal': {
      knowledgeBase: 'bd43603f89a68b10b214e1134ad253e2',
      category: 'de43ec3be4228b10d8cbab474fd09805'
    },
    'personal-offshore': {
      knowledgeBase: '0643a03f89a68b10b214e1134ad2531d',
      category: '9a43ec3be4228b10d8cbab474fd0980c'
    }
  };
  var result = {
    matched: 0,
    leadership: 0,
    offshore: 0,
    alreadyCorrect: 0,
    requiresChange: 0,
    unexpected: 0
  };
  var grArticle = new GlideRecord('kb_knowledge');
  grArticle.addEncodedQuery('u_compendia_page_idSTARTSWITHleadership-portal:^ORu_compendia_page_idSTARTSWITHpersonal-offshore:');
  grArticle.query();
  while (grArticle.next()) {
    result.matched++;
    var slug = (grArticle.getValue('u_compendia_page_id') || '').split(':')[0];
    if (slug === 'leadership-portal') {
      result.leadership++;
    } else if (slug === 'personal-offshore') {
      result.offshore++;
    } else {
      result.unexpected++;
      continue;
    }
    if (grArticle.getValue('kb_knowledge_base') === targets[slug].knowledgeBase &&
        grArticle.getValue('kb_category') === targets[slug].category) {
      result.alreadyCorrect++;
    } else {
      result.requiresChange++;
    }
  }
  gs.print('SN_RESULT_START' + JSON.stringify(result) + 'SN_RESULT_END');
})();
