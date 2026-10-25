import unittest
from server.movement.movement import MovementProcessor

class MovementTest(unittest.TestCase):

    def setUp(self, sensitivity=800):
        self.service = MovementProcessor(sensitivity)
        self.sensitivity = sensitivity

    def test_movement_processor(self):
        dx, dy = 0.12, -0.03
        dx_pixel, dy_pixel = self.service.process(dx, dy)
        self.assertEqual(dx_pixel, dx*self.sensitivity)
        self.assertEqual(dy_pixel, dy*self.sensitivity)

    def test_default_sensitivity_is_4000(self):
        default_service = MovementProcessor()
        self.assertEqual(default_service.sensitivity, 4000)

    def test_sensitivity_can_be_updated(self):
        self.service.sensitivity = 2000
        dx_pixel, dy_pixel = self.service.process(0.1, 0.1)
        self.assertEqual(dx_pixel, 200)
        self.assertEqual(dy_pixel, 200)

    def test_subpixel_remainder_is_carried_over(self):
        self.service.sensitivity = 100

        dx_pixel, dy_pixel = self.service.process(0.005, 0.005)
        self.assertEqual((dx_pixel, dy_pixel), (0, 0))

        dx_pixel, dy_pixel = self.service.process(0.005, 0.005)
        self.assertEqual((dx_pixel, dy_pixel), (1, 1))

        dx_pixel, dy_pixel = self.service.process(0.005, 0.005)
        self.assertEqual((dx_pixel, dy_pixel), (0, 0))

    def test_negative_subpixel_remainder_is_carried_over(self):
        self.service.sensitivity = 100

        dx_pixel, dy_pixel = self.service.process(-0.005, -0.005)
        self.assertEqual((dx_pixel, dy_pixel), (0, 0))

        dx_pixel, dy_pixel = self.service.process(-0.005, -0.005)
        self.assertEqual((dx_pixel, dy_pixel), (-1, -1))

    def test_accumulated_output_preserves_total_displacement(self):
        self.service.sensitivity = 400
        inputs = [(0.0011, -0.0007)] * 25

        total_x = 0
        total_y = 0
        for dx, dy in inputs:
            dx_pixel, dy_pixel = self.service.process(dx, dy)
            total_x += dx_pixel
            total_y += dy_pixel

        self.assertAlmostEqual(total_x + self.service.carry_x, 0.0011 * 400 * 25)
        self.assertAlmostEqual(total_y + self.service.carry_y, -0.0007 * 400 * 25)
        self.assertGreater(total_x, 0)
        self.assertLess(total_y, 0)

if __name__ == "__main__":
    unittest.main()
