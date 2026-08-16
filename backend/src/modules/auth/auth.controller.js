const service = require('./auth.service');
const asyncHandler = require('../../utils/asyncHandler');

exports.registerStudent = asyncHandler(async (req, res) => {
  const result = await service.registerStudent(req.body, {
    ua: req.headers['user-agent'],
    ip: req.ip,
  });
  res.status(201).json(result);
});

exports.registerTeacher = asyncHandler(async (req, res) => {
  const result = await service.registerTeacher(req.body, {
    ua: req.headers['user-agent'],
    ip: req.ip,
  });
  res.status(201).json(result);
});

exports.login = asyncHandler(async (req, res) => {
  const result = await service.login(req.body, {
    ua: req.headers['user-agent'],
    ip: req.ip,
  });
  res.status(200).json(result);
});

exports.refresh = asyncHandler(async (req, res) => {
  const result = await service.refresh(req.body);
  res.status(200).json(result);
});

exports.logout = asyncHandler(async (req, res) => {
  await service.logout(req.body);
  res.status(204).send();
});

exports.me = asyncHandler(async (req, res) => {
  const result = await service.me({ id: req.user.sub, role: req.user.role });
  res.status(200).json({ user: result });
});
